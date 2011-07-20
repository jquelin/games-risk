#
# This file is part of Games-Risk
#
# This software is Copyright (c) 2008 by Jerome Quelin.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#
use 5.010;
use strict;
use warnings;

package Games::Risk::GUI::Board;
BEGIN {
  $Games::Risk::GUI::Board::VERSION = '3.112010';
}
# ABSTRACT: board gui component

use POE            qw{ Loop::Tk };
use Image::Magick;
use Image::Size;
use List::Util     qw{ min };
use MIME::Base64;
use Readonly;
use Tk;
use Tk::Balloon;
use Tk::JPEG;
use Tk::PNG;
use Tk::Sugar;

use Games::Risk::GUI::GameOver;
use Games::Risk::GUI::MoveArmies;
use Games::Risk::I18n      qw{ T };
use Games::Risk::Resources qw{ get_image };
use Games::Risk::Tk::Cards;
use Games::Risk::Tk::Continents;
use Games::Risk::Utils     qw{ $SHAREDIR };


use constant K => $poe_kernel;

Readonly my $WAIT_CLEAN_AI    => 1.000;
Readonly my $WAIT_CLEAN_HUMAN => 0.250;
Readonly my $FLASHDELAY       => 0.150;


#--
# Constructor

#
# my $id = Games::Risk::GUI->spawn( \%params );
#
# create a new window containing the board used for the game. refer
# to the embedded pod for an explanation of the supported options.
#
sub spawn {
    my (undef, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events - session
            _start               => \&_onpriv_start,
            _stop                => sub { warn "gui-board shutdown\n" },
            # private events - game
            _clean_attack                  => \&_onpriv_clean_attack,
            _country_redraw                => \&_onpub_country_redraw,
            # gui events
            _but_attack_done               => \&_ongui_but_attack_done,
            _but_attack_redo               => \&_ongui_but_attack_redo,
            _but_move_armies_done          => \&_ongui_but_move_armies_done,
            _but_place_armies_done         => \&_ongui_but_place_armies_done,
            _but_place_armies_redo         => \&_ongui_but_place_armies_redo,
            _canvas_attack_cancel          => \&_ongui_canvas_attack_cancel,
            _canvas_attack_from            => \&_ongui_canvas_attack_from,
            _canvas_attack_target          => \&_ongui_canvas_attack_target,
            _canvas_configure              => \&_ongui_canvas_configure,
            _canvas_move_armies_cancel     => \&_ongui_canvas_move_armies_cancel,
            _canvas_move_armies_from       => \&_ongui_canvas_move_armies_from,
            _canvas_move_armies_target     => \&_ongui_canvas_move_armies_target,
            _canvas_place_armies           => \&_ongui_canvas_place_armies,
            _canvas_place_armies_initial   => \&_ongui_canvas_place_armies_initial,
            _canvas_motion                 => \&_ongui_canvas_motion,
            _quit                          => \&_quit,
            _show_cards                    => \&_show_cards,
            _show_continents               => \&_show_continents,
            _show_help                     => \&_show_help,
            _window_close                  => \&_ongui_window_close,
            # public events
            attack                         => \&_onpub_attack,
            attack_info                    => \&_onpub_attack_info,
            attack_move                    => \&_onpub_attack_move,
            chnum                          => \&_onpub_country_redraw,
            chown                          => \&_onpub_country_redraw,
            flash_country                  => \&_onpub_flash_country,
            game_over                      => \&_onpub_game_over,
            load_map                       => \&_onpub_load_map,
            move_armies                    => \&_onpub_move_armies,
            move_armies_move               => \&_onpub_move_armies_move,
            place_armies                   => \&_onpub_place_armies,
            place_armies_initial           => \&_onpub_place_armies_initial,
            place_armies_initial_count     => \&_onpub_place_armies_initial_count,
            player_active                  => \&_onpub_player_active,
            player_add                     => \&_onpub_player_add,
            player_lost                    => \&_onpub_player_lost,
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events

#
# event: attack();
#
# request user to start attacking at will.
#
sub _onpub_attack {
    my ($h, $s) = @_[HEAP, SESSION];

    # update the gui to reflect the new state.
    my $c = $h->{canvas};
    $c->CanvasBind( '<1>', $s->postback('_canvas_attack_from') );
    $c->CanvasBind( '<3>', $s->postback('_canvas_attack_cancel') );
    $h->{labels}{attack}->configure(enabled);
    $h->{buttons}{attack_done}->configure(enabled);
    $h->{toplevel}->bind('<Key-Return>', $s->postback('_but_attack_done'));

    if ( defined($h->{src}) && defined($h->{dst})
        && $h->{src}->owner ne $h->{dst}->owner
        && $h->{src}->armies > 1 ) {
        $h->{buttons}{attack_redo}->configure(enabled);
        $h->{toplevel}->bind('<Key-space>', $s->postback('_but_attack_redo'));

        # auto-reattack?
        K->yield('_but_attack_redo') if $h->{auto_reattack} && $h->{src}->armies >= 4;

    } else {
        $h->{buttons}{attack_redo}->configure(disabled);
        $h->{toplevel}->bind('<Key-space>', undef);
    }

    # update status msg
    $h->{status} = T('Attacking from ...');
}


#
# event: attack_info($src, $dst, \@attack, \@defence);
#
# Give the result of $dst attack from $src: @attack and @defence dices
#
sub _onpub_attack_info {
    my ($h, $src, $dst, $attack, $defence) = @_[HEAP, ARG0..$#_];

    # update status msg
    $h->{status} = sprintf T('Attacking %s from %s'), $dst->name, $src->name;

    # update attack dices
    foreach my $i ( 1 .. 3 ) {
        my $d = $attack->[$i-1] // 0; #//padre
        $h->{labels}{"attack_$i"}->configure(-image=>get_image("dice-$d"));
    }

    # update defence dices
    foreach my $i ( 1 .. 2 ) {
        my $d = $defence->[$i-1] // 0; #//padre
        $h->{labels}{"defence_$i"}->configure(-image=>get_image("dice-$d"));
    }

    # draw a line on the canvas
    my $c = $h->{canvas};
    state $i = 0;
    my ($zoomx, $zoomy) = @{ $h->{zoom} };
    my $x1 = $src->coordx * $zoomx; my $y1 = $src->coordy * $zoomy;
    my $x2 = $dst->coordx * $zoomx; my $y2 = $dst->coordy * $zoomy;
    $c->createLine(
        $x1, $y1, $x2, $y2,
        -arrow => 'last',
        -tags  => ['attack', "attack$i"],
        -fill  => 'yellow', #$h->{curplayer}->color,
        -width => 4,
    );
    my $srcid = $src->id;
    #my $dstid = $dst->id;
    $c->raise('attack', 'all');
    $c->raise("country$srcid", 'attack');
    $c->idletasks;
    my $wait = $h->{curplayer}->type eq 'ai' ? $WAIT_CLEAN_AI : $WAIT_CLEAN_HUMAN;
    K->delay_set('_clean_attack' => $wait, $i);
    $i++;

    # update result labels
    my $ok  = get_image('actcheck16');
    my $nok = get_image('actcross16');
    my $nul = get_image('empty16');
    my $r1 = $attack->[0] <= $defence->[0] ? $nok : $ok;
    my $r2 = scalar(@$attack) >= 2 && scalar(@$defence) == 2
        ? $attack->[1] <= $defence->[1] ? $nok : $ok
        : $nul;
    $h->{labels}{result_1}->configure( -image => $r1 );
    $h->{labels}{result_2}->configure( -image => $r2 );
}


#
# event: attack_move
#
# Prevent user to re-attack till he moved the armies.
#
sub _onpub_attack_move {
    my $h = $_[HEAP];

    my $c = $h->{canvas};
    $h->{toplevel}->bind('<Key-space>', undef);  # can't re-attack
    $h->{toplevel}->bind('<Key-Return>', undef); # done attack
    $c->CanvasBind('<1>', undef);
    $c->CanvasBind('<3>', undef);
    $h->{labels}{attack}->configure(disabled);
    $h->{buttons}{attack_redo}->configure(disabled);
    $h->{buttons}{attack_done}->configure(disabled);

}


#
# event: chnum($country);
# event: chown($country);
#
# Force C<$country> to be redrawn: owner and number of armies.
#
sub _onpub_country_redraw {
    my ($h, $country) = @_[HEAP, ARG0];
    my $c = $h->{canvas};

    my $id    = $country->id;
    my $owner = $country->owner;
    my $fakein  = $h->{fake_armies_in}{$id}  // 0; #//padre
    my $fakeout = $h->{fake_armies_out}{$id} // 0; #//padre
    my $armies  = ($country->armies // 0) + $fakein - $fakeout; #//padre

    # FIXME: change radius to reflect number of armies
    my ($radius, $fill_color, $text) = defined $owner
            ? (8, $owner->color, $armies)
            : (6,       'white', '');

    $radius += min(16,$armies-1)/2;
    my ($zoomx, $zoomy) = @{ $h->{zoom} };
    my $x = $country->coordx * $zoomx;
    my $y = $country->coordy * $zoomy;
    my $x1 = $x - $radius; my $x2 = $x + $radius;
    my $y1 = $y - $radius; my $y2 = $y + $radius;

    # update canvas
    $c->delete( "country$id" );
    #  - circle
    $c->createOval(
        $x1, $y1, $x2, $y2,
        -fill    => $fill_color,
        -outline => 'black',
        -tags    => [ "country$id", 'circle' ],
    );

    #  - text
    $c->createText(
        $x, $y+1,
        -fill => 'white',
        -tags => [ "country$id", 'text' ],
        -text => $text,
    );

    $c->raise("country$id&&circle", 'all');
    $c->raise("country$id&&text",   'all');
}


#
# event: flash_country( $country )
#
# request $country to be flashed on the map. this is done by
# extracting the country from the greyscale image, and paint it in
# white on the canvas.
#
# event: flash_country( $country , [ $state, $left ] )
#
# once the image is created, the event yields itself back after
# $FLASHDELAY, and shows/hides the image depending on $state. when $left hits 0 (decremented each state change), the image is discarded.
#
sub _onpub_flash_country {
    my ($h, $country, $on, $left) = @_[HEAP, ARG0 .. $#_];
    my $c = $h->{canvas};

    # first time that the country is flashed
    if ( not defined $on ) {
        # load greyscale image...
        my $magick = Image::Magick->new;
        $magick->Read( Games::Risk->new->map->greyscale );

        # and paint everything that isn't the country in white
        my $id = $country->id;
        my $grey = "rgb($id,$id,$id)";
        $magick->FloodfillPaint(fuzz=>0, fill=>'white', bordercolor=>$grey, invert=>1);
        $magick->Negate;                        # turn white in black
        $magick->Transparent( color=>'black' ); # mark black as transparent

        # resize the image to fit canvas zoom
        my ($zoomx, $zoomy) = @{ $h->{zoom} };
        my $width  = $magick->Get('width');
        my $height = $magick->Get('height');
        $magick->Scale(width=>$width * $zoomx, height=>$height * $zoomy);

        # remove all the uninteresting bits around the country itself
        $magick->Trim;
        my $coordx = $magick->Get('page.x');
        my $coordy = $magick->Get('page.y');
        $magick->Set(page=>'0x0+0+0');          # reset the page (resize image to trimmed zone)

        # create the image and display it on the canvas
        my $img = $c->Photo( -data => encode_base64( $magick->ImageToBlob ) );
        $c->createImage($coordx, $coordy, -anchor=>'nw', -image=>$img, -tags=>["flash$country"]);

        $on   = 1;
        $left = 8;
    }
    my $method = $on ? 'raise' : 'lower';
    $c->$method("flash$country", 'background' );
    if ( $left ) {
        K->delay( flash_country => $FLASHDELAY => $country, !$on, $left-1 );
    } else {
        $c->delete( "flash$country" );
    }
}


#
# event: game_over( $player );
#
# sent when $player has won the game.
#
sub _onpub_game_over {
    my ($h, $winner) = @_[HEAP, ARG0];

    # update gui
    my $c = $h->{canvas};
    $h->{toplevel}->bind('<Key-space>', undef);  # can't re-attack
    $h->{toplevel}->bind('<Key-Return>', undef); # done attack
    $c->CanvasBind('<1>', undef);
    $c->CanvasBind('<3>', undef);
    $h->{labels}{attack}->configure(disabled);
    $h->{buttons}{attack_redo}->configure(disabled);
    $h->{buttons}{attack_done}->configure(disabled);

    # announce the winner
    Games::Risk::GUI::GameOver->spawn({
        parent => $h->{toplevel},
        winner => $winner,
    });
}


#
# event: load_map( $map );
#
# load background and greyscale from $map. request countries to display
# their data.
#
sub _onpub_load_map {
    my ($h, $s, $map) = @_[HEAP, SESSION, ARG0];
    my $c = $h->{canvas};

    # remove everything
    $c->delete('all');
    $c->CanvasBind('<Configure>', undef);

    # create background image
    my $img_path = $map->background;
    my ($width, $height) = imgsize($img_path);
    # FIXME: adapt to current window width/height
    my $img = $c->Photo( -file=>$img_path );
    $c->configure(-width => $width, -height => $height);
    $c->createImage(0, 0, -anchor=>'nw', -image=>$img, -tags=>['background']);

    # store zoom information
    $h->{orig_bg_size} = [$width, $height];
    $h->{zoom}         = [1, 1];

    # create capitals
    K->yield('_country_redraw', $_) foreach $map->countries;

    # load greyscale image
    $h->{greyscale} = $c->Photo(-file=>$map->greyscale);

    # allow the canvas to update itself & reinstall callback.
    $c->idletasks;
    $c->CanvasBind('<Configure>', [$s->postback('_canvas_configure'), Ev('w'), Ev('h')] );

    # store map and say we're done
    $h->{map} = $map;
    K->post('risk', 'map_loaded');
}


#
# event: move_armies()
#
# request user to move armies if he wants to.
#
sub _onpub_move_armies {
    my ($h, $s) = @_[HEAP, SESSION];

    # initialiaze moves
    $h->{move_armies} = [];
    $h->{fake_armies_in}  = {};
    $h->{fake_armies_out} = {};

   # update the gui to reflect the new state.
    my $c = $h->{canvas};
    $c->CanvasBind( '<1>', $s->postback('_canvas_move_armies_from') );
    $c->CanvasBind( '<3>', $s->postback('_canvas_move_armies_cancel') );
    $h->{labels}{move_armies}->configure(enabled);
    $h->{buttons}{move_armies_done}->configure(enabled);
    $h->{status} = T('Moving armies from...');
    $h->{toplevel}->bind('<Key-Return>', $s->postback('_but_move_armies_done'));
}


#
# event: move_armies_move($src, $dst, $nb);
#
# request user to move $nb armies from $src to $dst.
#
sub _onpub_move_armies_move {
    my ($h, $s, $src, $dst, $nb) = @_[HEAP, SESSION, ARG0..$#_];

    my $srcid = $src->id;
    my $dstid = $dst->id;

    # update the countries
    $h->{fake_armies_out}{$srcid} += $nb;
    $h->{fake_armies_in}{$dstid}  += $nb;

    # save move for later
    push @{ $h->{move_armies} }, [$src, $dst, $nb];

    # update the gui
    K->yield('chnum', $src);
    K->yield('chnum', $dst);
    my $c = $h->{canvas};
    $c->CanvasBind( '<1>', $s->postback('_canvas_move_armies_from') );
    $c->CanvasBind( '<3>', $s->postback('_canvas_move_armies_cancel') );
    $h->{buttons}{move_armies_done}->configure(enabled);
    $h->{toplevel}->bind('<Key-Return>', $s->postback('_but_move_armies_done'));
    $h->{status} = T('Moving armies from...');
}


#
# event: place_armies( $nb [, $continent] );
#
# request user to place $nb armies on her countries (maybe within
# $continent if supplied).
#
sub _onpub_place_armies {
    my ($h, $s, $nb, $continent) = @_[HEAP, SESSION, ARG0, ARG1];

    my $name = defined $continent ? $continent->name : 'free';
    $h->{armies}{$name}        += $nb;
    $h->{armies_backup}{$name} += $nb;   # to allow reinforcements redo

    # update the gui to reflect the new state.
    my $c = $h->{canvas};
    $c->CanvasBind( '<1>', $s->postback('_canvas_place_armies',  1) );
    $c->CanvasBind( '<3>', $s->postback('_canvas_place_armies', -1) );
    $c->CanvasBind( '<4>', $s->postback('_canvas_place_armies',  1) );
    $c->CanvasBind( '<5>', $s->postback('_canvas_place_armies', -1) );
    $h->{labels}{place_armies}->configure(enabled);

    # update status msg
    my $count = 0;
    $count += $_ for values %{ $h->{armies} };
    $h->{status} = sprintf T("%s armies left to place"), $count;
}


#
# event: place_armies_initial;
#
# request user to place 1 armies on her countries. this is initial
# reinforcement, so there's no limit on where to put the army, and
# armies are put one by one.
#
sub _onpub_place_armies_initial {
    my ($h, $s) = @_[HEAP, SESSION, ARG0];

    my $c = $h->{canvas};
    $c->CanvasBind( '<1>', $s->postback('_canvas_place_armies_initial') );
}


#
# event: place_armies_initial_count( $nb );
#
# request user to place $nb armies on her countries. this is
# initial armies placement:
#  - no restriction on where
#  - armies get placed one by one
#
# this event just allows the gui to inform user how many armies will be
# placed initially.
#
sub _onpub_place_armies_initial_count {
    my ($h, $nb) = @_[HEAP, ARG0];
    $h->{status} = sprintf T("%s armies left to place"), $nb;
    $h->{armies_initial} = $nb;
}


#
# event: player_active( $player );
#
# change player labels so that previous player is inactive, and new
# active one is $player.
#
sub _onpub_player_active {
    my ($h, $new) = @_[HEAP, ARG0];

    my $plabels = $h->{labels}{players};
    my $old = $h->{curplayer};
    $plabels->{ $old->name }->configure(-image=>get_image('empty16')) if defined $old;
    $plabels->{ $new->name }->configure(-image=>get_image('player-active'));
    $h->{curplayer} = $new;
}


#
# event: player_add($player)
#
# create a label for $player, with tooltip information.
#
sub _onpub_player_add {
    my ($h, $player) = @_[HEAP, ARG0];

    # create label
    my $f = $h->{frames}{players};
    my $label = $f->Label(
        -bg    => $player->color,
        -image => get_image('empty16'),
    )->pack(left);
    $h->{labels}{players}{ $player->name } = $label;

    # associate tooltip
    my $tooltip = $player->name // ''; # FIXME: padre syntax hilight gone wrong /
    given ($player->type) {
        when ('human') {
            $tooltip .= ' (' . T('human') . ')';
        }

        when ('ai') {
            my $ai = $player->ai;
            my $difficulty  = $ai->difficulty;
            my $description = $ai->description;
            $tooltip .= ' (' . sprintf(T('computer - %s'), $difficulty). ")\n$description";
        }

        default { $tooltip = '?'; }
    }
    $h->{balloon}->attach($label, -msg=>$tooltip);
}


#
# event: player_lost($player)
#
# mark $player as lost.
#
sub _onpub_player_lost {
    my ($h, $player) = @_[HEAP, ARG0];

    # update gui
    my $name = $player->name;
    $h->{labels}{players}{$name} ->configure( -image => get_image('player-lost') );
    $h->{status} = sprintf T("Player %s has lost"), $name;
}


# -- private events

#
# event: _clean_attack( $i )
#
# remove line corresponding to attack $i from canvas.
#
sub _onpriv_clean_attack {
    my ($h, $i) = @_[HEAP, ARG0];
    $h->{canvas}->delete("attack$i");
}


#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my ($h, $s, $args) = @_[HEAP, SESSION, ARG0];

    K->alias_set('board');
    my $top = $h->{toplevel} = $args->{toplevel};
    $top->title('prisk');
    my $icon = $SHAREDIR->file('icons', '32', 'prisk.png');
    my $mask = $SHAREDIR->file('icons', '32', 'prisk-mask.xbm');
    $top->iconimage( $top->Photo(-file=>$icon) );
    $top->iconmask( '@' . $mask );

    #-- various resources

    # ballon
    $h->{balloon} = $top->Balloon;


    #-- menu
    $top->optionAdd('*tearOff', 'false'); # no tear-off menus
    my $menubar = $top->Menu;
    $top->configure(-menu => $menubar );

    my $game = $menubar->cascade(-label => T('~Game'));
    $game->command(
        -label       => T('~Close'),
        -accelerator => 'Ctrl+W',
        -command     => $s->postback('_window_close'),
        -image       => $top->Photo(-file=>$SHAREDIR->file('icons', '16', 'close.png')),
        -compound    => 'left',
    );
    $top->bind('<Control-w>', $s->postback('_window_close'));
    $top->bind('<Control-W>', $s->postback('_window_close'));

    $game->command(
        -label       => T('~Quit'),
        -accelerator => 'Ctrl+Q',
        -command     => $s->postback('_quit'),
        -image       => $top->Photo(-file=>$SHAREDIR->file('icons', '16', 'exit.png')),
        -compound    => 'left',
    );
    $top->bind('<Control-q>', $s->postback('_quit'));
    $top->bind('<Control-Q>', $s->postback('_quit'));

    my $view = $menubar->cascade(-label => T('~View'));
    $view->command(
        -label       => T('~Cards'),
        -accelerator => 'F5',
        -command     => $s->postback('_show_cards'),
        -image       => $top->Photo(-file=>$SHAREDIR->file('icons', '16', 'cards.png')),
        -compound    => 'left',
    );
    $top->bind('<F5>', $s->postback('_show_cards'));
    $view->command(
        -label       => T('C~ontinents'),
        -accelerator => 'F6',
        -command     => $s->postback('_show_continents'),
        -image       => $top->Photo(-file=>$SHAREDIR->file('icons', '16', 'continents.png')),
        -compound    => 'left',
    );
    $top->bind('<F6>', $s->postback('_show_continents'));

    my $help = $menubar->cascade(-label => T('~Help'));
    $help->command(
        -label       => T('~Help'),
        -accelerator => 'F1',
        -image       => $top->Photo(-file=>$SHAREDIR->file('icons', '16', 'help.png')),
        -compound    => 'left',
        -command     => $s->postback('_show_help'),
    );
    $top->bind('<F1>', $s->postback('_show_help'));
    $help->command(
        -label       => T('~About'),
        -image       => $top->Photo(-file=>$SHAREDIR->file('icons', '16', 'about.png')),
        -compound    => 'left',
        -command     => sub {
            require Games::Risk::Tk::About;
            Games::Risk::Tk::About->new({parent=>$top});
        },
    );


    #$h->{menu}{view} = $menubar->entrycget(1, '-menu');


    #-- main frames
    my $fleft  = $top->Frame->pack(left,  xfill2);
    my $fright = $top->Frame->pack(right, fill2);


    #-- frame for game state
    my $fgs = $fleft->Frame->pack(top, fillx);
    $fgs->Label(-text=>T('Game state: '))->pack(left);
    my $labp = $fgs->Label(-text=>T('place armies'), disabled)->pack(left, xfill2);
    my $but_predo = $fgs->Button(
        -command => $s->postback('_but_place_armies_redo'),
        -image   => get_image('actreload16'),
        disabled,
    )->pack(left);
    my $but_pdone = $fgs->Button(
        -command => $s->postback('_but_place_armies_done'),
        -image   => get_image('navforward16'),
        disabled,
    )->pack(left);
    my $laba = $fgs->Label(-text=>T('attack'), disabled)->pack(left, xfill2);
    my $but_aredo = $fgs->Button(
        -command => $s->postback('_but_attack_redo'),
        -image   => get_image('actredo16'),
        disabled,
    )->pack(left);
    my $but_adone = $fgs->Button(
        -command => $s->postback('_but_attack_done'),
        -image   => get_image('navforward16'),
        disabled,
    )->pack(left);
    my $labm = $fgs->Label(-text=>T('move armies'), disabled)->pack(left, xfill2);
    my $but_mdone = $fgs->Button(
        -command => $s->postback('_but_move_armies_done'),
        -image   => get_image('playstop16'),
        disabled,
    )->pack(left);
    $h->{labels}{place_armies} = $labp;
    $h->{labels}{attack}       = $laba;
    $h->{labels}{move_armies}  = $labm;
    $h->{buttons}{place_armies_redo} = $but_predo;
    $h->{buttons}{place_armies_done} = $but_pdone;
    $h->{buttons}{attack_redo}       = $but_aredo;
    $h->{buttons}{attack_done}       = $but_adone;
    $h->{buttons}{move_armies_done}  = $but_mdone;
    $h->{balloon}->attach($but_predo, -msg=>T('undo all'));
    $h->{balloon}->attach($but_pdone, -msg=>T('ready for attack'));
    $h->{balloon}->attach($but_aredo, -msg=>T('attack again'));
    $h->{balloon}->attach($but_adone, -msg=>T('consolidate'));
    $h->{balloon}->attach($but_mdone, -msg=>T('turn finished'));


    #-- canvas
    my $c = $fleft->Canvas->pack(top,xfill2);
    $h->{canvas} = $c;
    $c->CanvasBind( '<Motion>', [$s->postback('_canvas_motion'), Ev('x'), Ev('y')] );
    # removing class bindings
    foreach my $button ( qw{ 4 5 6 7 } ) {
        $top->bind('Tk::Canvas', "<Button-$button>",       undef);
        $top->bind('Tk::Canvas', "<Shift-Button-$button>", undef);
    }
    foreach my $key ( qw{ Down End Home Left Next Prior Right Up } ) {
        $top->bind('Tk::Canvas', "<Key-$key>", undef);
        $top->bind('Tk::Canvas', "<Control-Key-$key>", undef);
    }


    #-- bottom frame
    # the status bar
    $h->{status} = '';
    my $fbot = $fleft->Frame->pack(bottom, fillx);
    $fbot->Label(
        -anchor       =>'w',
        -textvariable => \$h->{status},
    )->pack(left,xfillx, pad1);

    # label to display country pointed by mouse
    $h->{country}       = undef;
    $h->{country_label} = '';
    $fbot->Label(
        -anchor       => 'e',
        -textvariable => \$h->{country_label},
    )->pack(right, xfillx, pad1);


     #-- players frame
    my $fpl = $fright->Frame->pack(top);
    $fpl->Label(-text=>T('Players'))->pack(top);
    my $fplist = $fpl->Frame->pack(top);
    $h->{frames}{players} = $fplist;


    #-- dices frame
    my $fdice = $fright->Frame->pack(top,fillx,pady(10));
    $fdice->Label(-text=>T('Dice arena'))->pack(top,fillx);
    my $fd1 = $fdice->Frame->pack(top,fill2);
    my $a1 = $fd1->Label(-image=>get_image('dice-0'))->pack(left);
    my $a2 = $fd1->Label(-image=>get_image('dice-0'))->pack(left);
    my $a3 = $fd1->Label(-image=>get_image('dice-0'))->pack(left);
    my $fd3 = $fdice->Frame->pack(top,fill2);
    my $r1 = $fd3->Label(
        -image => get_image('empty16'),
        -width => 38,
    )->pack(left);
    my $r2 = $fd3->Label(
        -image => get_image('empty16'),
        -width => 38,
    )->pack(left);
    my $fd2 = $fdice->Frame->pack(top,fill2);
    my $d1 = $fd2->Label(-image=>get_image('dice-0'))->pack(left);
    my $d2 = $fd2->Label(-image=>get_image('dice-0'))->pack(left);
    $h->{labels}{attack_1}  = $a1;
    $h->{labels}{attack_2}  = $a2;
    $h->{labels}{attack_3}  = $a3;
    $h->{labels}{result_1}  = $r1;
    $h->{labels}{result_2}  = $r2;
    $h->{labels}{defence_1} = $d1;
    $h->{labels}{defence_2} = $d2;

    #-- redo checkbox
    $h->{auto_reattack} = 0; # FIXME: from config
    my $cb_reattack = $fright->Checkbutton(
        -text     => T('Auto-reattack'),
        -variable => \$h->{auto_reattack},
        -anchor   => 'w',
    )->pack(top,fillx);
    $h->{balloon}->attach($cb_reattack, -msg=>T('Automatically re-do last attack if attacker still has more than 3 armies'));

    #-- trap close events
    $top->protocol( WM_DELETE_WINDOW => $s->postback('_window_close') );

    #-- other window
    Games::Risk::Tk::Cards->new({parent=>$top});
    Games::Risk::Tk::Continents->new({parent=>$top});
    Games::Risk::GUI::MoveArmies->spawn({parent=>$top});

    #-- say that we're done
    K->yield('load_map', $args->{map});
}

# -- gui events

#
# event: _but_attack_done();
#
# Called when all planned attacks are finished.
#
sub _ongui_but_attack_done {
    my $h = $_[HEAP];

    # reset src & dst
    $h->{src} = undef;
    $h->{dst} = undef;

    # update gui
    $h->{status} = '';
    my $c = $h->{canvas};
    $h->{toplevel}->bind('<Key-space>', undef);  # can't re-attack
    $h->{toplevel}->bind('<Key-Return>', undef); # done attack
    $c->CanvasBind('<1>', undef);
    $c->CanvasBind('<3>', undef);
    $h->{labels}{attack}->configure(disabled);
    $h->{buttons}{attack_redo}->configure(disabled);
    $h->{buttons}{attack_done}->configure(disabled);

    # signal controller
    K->post('risk', 'attack_end');
}


#
# event: _but_attack_redo();
#
# attack again the same destination from the same source.
#
sub _ongui_but_attack_redo {
    my $h = $_[HEAP];

    # signal controller
    $h->{toplevel}->bind('<Key-space>', undef);
    K->post('risk', 'attack', $h->{src}, $h->{dst});
}


#
# event: _but_move_armies_done()
#
# moving armies at the end of the turn is finished.
#
sub _ongui_but_move_armies_done {
    my $h = $_[HEAP];

    # update gui
    my $c = $h->{canvas};
    $h->{toplevel}->bind('<Key-Return>', undef);
    $c->CanvasBind( '<1>', undef );
    $c->CanvasBind( '<3>', undef );
    $h->{labels}{move_armies}->configure(disabled);
    $h->{buttons}{move_armies_done}->configure(disabled);
    $h->{status} = '';

    # signal controller
    foreach my $move ( @{ $h->{move_armies} } ) {
        my ($src, $dst, $nb) = @$move;
        K->post('risk', 'move_armies', $src, $dst, $nb);
    }
    K->post('risk', 'armies_moved');

    # reset internals
    $h->{move_armies} = [];
    $h->{fake_armies_in}  = {};
    $h->{fake_armies_out} = {};
}


#
# event: _but_place_armies_done();
#
# Called when all armies are placed correctly.
#
sub _ongui_but_place_armies_done {
    my $h = $_[HEAP];

    # check if we're done
    my $nb = 0;
    $nb += $_ for values %{ $h->{armies} };
    if ( $nb != 0 ) {
        warn 'should not be there!';
        return;
    }

    # update gui
    $h->{status} = '';
    my $c = $h->{canvas};
    $c->CanvasBind('<1>', undef);
    $c->CanvasBind('<3>', undef);
    $c->CanvasBind('<4>', undef);
    $c->CanvasBind('<5>', undef);
    $h->{labels}{place_armies}->configure(disabled);
    $h->{buttons}{place_armies_redo}->configure(disabled);
    $h->{buttons}{place_armies_done}->configure(disabled);
    $h->{toplevel}->bind('<Key-Escape>', undef); # redo armies placement
    $h->{toplevel}->bind('<Key-Return>', undef); # done armies placement

    # request controller to update
    foreach my $id ( keys %{ $h->{fake_armies_in} } ) {
        next if $h->{fake_armies_in}{$id} == 0; # don't send null reinforcements
        my $country = $h->{map}->country_get($id);
        K->post('risk', 'armies_placed', $country, $h->{fake_armies_in}{$id});
    }
    $h->{armies} = {};
    $h->{armies_backup} = {};
    $h->{fake_armies_in} = {};
}


#
# event: _but_place_armies_redo();
#
# Called when user wants to restart from scratch reinforcements placing.
#
sub _ongui_but_place_armies_redo {
    my ($h, $s) = @_[HEAP, SESSION];

    foreach my $id ( keys %{ $h->{fake_armies_in} } ) {
        next if $h->{fake_armies_in}{$id} == 0;
        delete $h->{fake_armies_in}{$id};
        my $country = $h->{map}->country_get($id);
        K->yield('chnum', $country);
    }

    # forbid button next phase to be clicked
    $h->{buttons}{place_armies_done}->configure(disabled);
    # allow adding armies
    $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_place_armies', 1) );
    $h->{canvas}->CanvasBind( '<4>', $s->postback('_canvas_place_armies', 1) );

    # reset initials
    my $nb = 0;
    foreach my $k ( keys %{ $h->{armies_backup} } ) {
        my $v = $h->{armies_backup}{$k};
        $h->{armies}{$k} = $v; # restore initial value
        $nb += $v;
    }
    $h->{fake_armies_in} = {};

    # updatee status
    $h->{status} = sprintf T("%s armies left to place"), $nb;
}


#
# event: _canvas_attack_from();
#
# Called when user wants to select a country to attack from.
#
sub _ongui_canvas_attack_from {
    my ($h, $s) = @_[HEAP, SESSION];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};

    # checks...
    return unless defined $country;
    return if $country->owner->name ne $curplayer->name; # country owner
    return if $country->armies == 1;

    # record attack source
    $h->{src} = $country;

    # update status msg
    $h->{status} = sprintf T('Attacking ... from %s'), $country->name;

    $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_attack_target') );
}


#
# event: _canvas_attack_cancel();
#
# Called when user wants to deselect a country to attack.
#
sub _ongui_canvas_attack_cancel {
    my ($h, $s) = @_[HEAP, SESSION];

    # cancel attack source
    $h->{src} = undef;

    # update status msg
    $h->{status} = sprintf T('Attacking from ...');

    $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_attack_from') );
}


#
# event: _canvas_attack_target();
#
# Called when user wants to select target for her attack.
#
sub _ongui_canvas_attack_target {
   my $h = $_[HEAP];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};

    # checks...
    return unless defined $country;
    if ( $country->owner->name eq $curplayer->name ) {
        # we own this country too, let's just change source of attack.
        K->yield('_canvas_attack_from');
        return;
    }
    return unless $country->is_neighbour( $h->{src} );

    # update status msg
    $h->{status} = sprintf T('Attacking %s from %s'), $country->name, $h->{src}->name;

    # store opponent
    $h->{dst} = $country;

    # update gui to reflect new state
    $h->{canvas}->CanvasBind('<1>', undef);
    $h->{canvas}->CanvasBind('<3>', undef);
    $h->{buttons}{attack_done}->configure(disabled);
    $h->{toplevel}->bind('<Key-Return>', undef);

    # signal controller
    K->post('risk', 'attack', $h->{src}, $country);
}


#
# event: _canvas_configure( undef, [$canvas, $w, $h] );
#
# Called when canvas is reconfigured. new width and height available
# with ($w, $h). note that reconfigure is also window motion.
#
sub _ongui_canvas_configure {
    my ($h, $args) = @_[HEAP, ARG1];
    my ($c, $neww, $newh) = @$args;

    # create a new image resized to fit new dims
    my $magick = Image::Magick->new;
    $magick->Read( $h->{map}->background );
    $magick->Scale(width=>$neww, height=>$newh);

    # install this new image inplace of previous background
    my $img = $c->Photo( -data => encode_base64( $magick->ImageToBlob ) );
    $c->delete('background');
    $c->createImage(0, 0, -anchor=>'nw', -image=>$img, -tags=>['background']);
    $c->lower('background', 'all');

    # update zoom factors. note that we don't want to resize greyscale
    # image since a) it takes time, which is unneeded since this image
    # is not displayed and b) greyscale are quite close from country to
    # country, and resizing will blur this to the point that it's no
    # longer usable. therefore, just storing a zoom factor and using it
    # will be enough for greyscale.
    my ($origw, $origh) = @{ $h->{orig_bg_size} };
    $h->{zoom} = [ $neww/$origw, $newh/$origh ];

    # force country redraw, for them to be correctly placed on the new
    # map.
    K->yield('_country_redraw', $_) foreach $h->{map}->countries;
}


#
# event: _canvas_motion( undef, [$canvas, $x, $y] );
#
# Called when mouse is moving over the $canvas at coords ($x,$y).
#
sub _ongui_canvas_motion {
    my ($h, $args) = @_[HEAP, ARG1];

    my (undef, $x,$y) = @$args; # first param is canvas

    # correct with zoom factor
    my ($zoomx, $zoomy) = @{ $h->{zoom} // [1,1] }; #//padre
    $x /= $zoomx;
    $y /= $zoomy;

    # get greyscale pointed by mouse, this may die if moving too fast
    # outside of the canvas. we just need the 'red' component, since
    # green and blue will be the same.
    my $grey = 0;
    eval { ($grey) = $h->{greyscale}->get($x,$y) };
    return unless defined $h->{map};
    my $country    = $h->{map}->country_get($grey);

    # update country and country label
    $h->{country}       = $country;  # may be undef
    $h->{country_label} = defined $country
        ? join(' - ', $country->continent->name, $country->name)
        : '';
}


#
# event: _canvas_move_armies_cancel();
#
# Called when user wants to deselect a country to move from.
#
sub _ongui_canvas_move_armies_cancel {
    my ($h, $s) = @_[HEAP, SESSION];

    # cancel attack source
    $h->{src} = undef;

    # update status msg
    $h->{status} = T('Moving armies from ...');

    # canvas click now selects the source
    $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_move_armies_from') );
}


#
# event: _canvas_move_armies_from();
#
# Called when user selects country to move armies from.
#
sub _ongui_canvas_move_armies_from {
    my ($h, $s) = @_[HEAP, SESSION];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};

    # checks...
    return unless defined $country;
    my $id = $country->id;
    return if $country->owner->name ne $curplayer->name; # country owner
    return if $country->armies - ($h->{fake_armies_out}{$id}//0) == 1; # FIXME: padre syntax hilight gone wrong /

    # record move source
    $h->{src} = $country;

    # update status msg
    $h->{status} = sprintf T('Moving armies from %s to ...'), $country->name;

    $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_move_armies_target') );
}


#
# event: _canvas_move_armies_target();
#
# Called when user wants to select target for her armies move.
#
sub _ongui_canvas_move_armies_target {
   my $h = $_[HEAP];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};

    # checks...
    return unless defined $country;
    return if $country->owner->name ne $curplayer->name;
    return unless $country->is_neighbour( $h->{src} );

    # update status msg
    $h->{status} = sprintf T('Moving armies from %s to %s'), $h->{src}->name, $country->name;

    # store opponent
    $h->{dst} = $country;

    # update gui to reflect new state
    $h->{canvas}->CanvasBind('<1>', undef);
    $h->{canvas}->CanvasBind('<3>', undef);
    $h->{buttons}{move_armies_done}->configure(disabled);
    $h->{toplevel}->bind('<Key-Return>', undef);

    # request user how many armies to move
    my $src = $h->{src};
    my $max = $src->armies - 1 - ($h->{fake_armies_out}{ $src->id }//0); # FIXME: padre syntax hilight gone wrong /
    K->post('move-armies', 'ask_move_armies', $h->{src}, $country, $max);
}


#
# event: _canvas_place_armies( [ $diff ] );
#
# Called when mouse click on the canvas during armies placement.
# Update "fake armies" to place $diff (may be negative) army on the
# current country.
#
sub _ongui_canvas_place_armies {
    my ($h, $s, $args) = @_[HEAP, SESSION, ARG0];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};
    return unless defined $country;
    my $id        = $country->id;
    my ($diff)    = @$args;

    # checks...
    return if $country->owner->name ne $curplayer->name; # country owner
    return if $diff + ($h->{fake_armies_in}{$id}//0) < 0;   # negative count (free army move! :-) ) # FIXME: padre syntax hilight gone wrong /

    # update armies count
    my $name = $country->continent->name;
    if ( exists $h->{armies}{$name} ) {
        $h->{armies}{$name} -= $diff;
        # FIXME: check if possible, otherwise default to free
    } else {
        $h->{armies}{free}  -= $diff;
        # FIXME: check if possible
    }

    # redraw country.
    $h->{fake_armies_in}{ $country->id } += $diff;
    K->yield( 'chnum', $country );

    # allow redo button
    $h->{buttons}{place_armies_redo}->configure(enabled);
    $h->{toplevel}->bind('<Key-Escape>', $s->postback('_but_place_armies_redo'));

    # check if we're done
    my $nb = 0;
    $nb += $_ for values %{ $h->{armies} };
    $h->{status} = sprintf T("%s armies left to place"), $nb;
    if ( $nb == 0 ) {
        # allow button next phase to be clicked
        $h->{buttons}{place_armies_done}->configure(enabled);
        $h->{toplevel}->bind('<Key-Return>', $s->postback('_but_place_armies_done'));
        # forbid adding armies
        $h->{canvas}->CanvasBind('<1>', undef);
        $h->{canvas}->CanvasBind('<4>', undef);

    } else {
        # forbid button next phase to be clicked
        $h->{buttons}{place_armies_done}->configure(disabled);
        # allow adding armies
        $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_place_armies', 1) );
        $h->{canvas}->CanvasBind( '<4>', $s->postback('_canvas_place_armies', 1) );
    }
}


#
# event: _canvas_place_armies_initial();
#
# Called when mouse click on the canvas during initial armies placement.
# Will request controller to place one army on the current country.
#
sub _ongui_canvas_place_armies_initial {
    my $h = $_[HEAP];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};

    # check country owner
    return unless defined $country;
    return if $country->owner->name ne $curplayer->name;

    # change canvas bindings
    $h->{canvas}->CanvasBind('<1>', undef);

    # update gui
    $h->{armies_initial}--;
    my $nb = $h->{armies_initial};
    $h->{status} = $nb ? sprintf( T("%s armies left to place"), $nb) : '';

    # tell controller that we've placed an army. controller will then
    # ask us to redraw the country.
    K->post('risk', 'initial_armies_placed', $country, 1);
}


#
# _quit()
#
# request whole game to be shut down.
#
sub _quit {
    # FIXME: cleaner way of exiting?
    exit;
}


#
# _show_cards()
#
# request card window to be shown/hidden.
#
sub _show_cards {
    K->post('cards', 'visibility_toggle');
}


#
# _show_continents()
#
# request continents window to be shown/hidden.
#
sub _show_continents {
    K->post('continents', 'visibility_toggle');
}

#
# _show_about()
#
# request Help/About window to be shown/hidden.
#
sub _show_help {
    my $h = $_[HEAP];
    require Games::Risk::Tk::Help;
    Games::Risk::Tk::Help->new({parent=>$h->{toplevel}});
}


#
# event: _window_close()
#
# called when user wants to close the window.
#
sub _ongui_window_close {
    my $h = $_[HEAP];

    # close window
    $h->{toplevel}->destroy;

    # remove all possible pending events - such as attack vector
    # cleaning.
    K->alarm_remove_all;

    # remove aliases & shut down the other windows
    K->alias_remove('board');
    K->post('risk', 'shutdown');

    # start another game
    K->post('startup', 'new_game');
}


1;



=pod

=head1 NAME

Games::Risk::GUI::Board - board gui component

=head1 VERSION

version 3.112010

=head1 SYNOPSIS

    my $id = Games::Risk::GUI::Board->spawn(\%params);

=head1 DESCRIPTION

This class implements a poe session responsible for the board part of
the GUI. It features a map and various controls to drive the action.

=head1 METHODS

=head2 my $id = Games::Risk::GUI::Board->spawn( )

=head1 EVENTS

=head2 Events received

=over 4

=item * country_redraw( $country )

Force C<$country> to be redrawn: owner and number of armies.

=back

=head1 SEE ALSO

L<Games::Risk>.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__


