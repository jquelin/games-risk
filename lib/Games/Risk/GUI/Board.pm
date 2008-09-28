#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI::Board;

use 5.010;
use strict;
use warnings;

use File::Basename qw{ fileparse };
use Games::Risk::GUI::Cards;
use Games::Risk::GUI::Constants;
use Games::Risk::GUI::GameOver;
use Games::Risk::GUI::MoveArmies;
use Image::Resize;
use Image::Size;
use List::Util     qw{ min };
use MIME::Base64;
use Module::Util   qw{ find_installed };
use POE;
use Readonly;
use Tk;
use Tk::Balloon;
use Tk::JPEG;
use Tk::PNG;

use aliased 'POE::Kernel' => 'K';

Readonly my $WAIT_CLEAN_AI    => 1.000;
Readonly my $WAIT_CLEAN_HUMAN => 0.250;


#--
# Constructor

#
# my $id = Games::Risk::GUI->spawn( \%params );
#
# create a new window containing the board used for the game. refer
# to the embedded pod for an explanation of the supported options.
#
sub spawn {
    my ($type, $args) = @_;

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
            _window_close                  => \&_ongui_window_close,
            # public events
            attack                         => \&_onpub_attack,
            attack_info                    => \&_onpub_attack_info,
            attack_move                    => \&_onpub_attack_move,
            chnum                          => \&_onpub_country_redraw,
            chown                          => \&_onpub_country_redraw,
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
    $h->{labels}{attack}->configure(@ENON);
    $h->{buttons}{attack_done}->configure(@ENON);
    $h->{toplevel}->bind('<Key-Return>', $s->postback('_but_attack_done'));

    if ( defined($h->{src}) && defined($h->{dst})
        && $h->{src}->owner ne $h->{dst}->owner
        && $h->{src}->armies > 1 ) {
        $h->{buttons}{attack_redo}->configure(@ENON);
        $h->{toplevel}->bind('<Key-space>', $s->postback('_but_attack_redo'));
    } else {
        $h->{buttons}{attack_redo}->configure(@ENOFF);
        $h->{toplevel}->bind('<Key-space>', undef);
    }

    # update status msg
    $h->{status} = 'Attacking from ...';
}


#
# event: attack_info($src, $dst, \@attack, \@defence);
#
# Give the result of $dst attack from $src: @attack and @defence dices
#
sub _onpub_attack_info {
    my ($h, $src, $dst, $attack, $defence, $loss_src, $loss_dst) = @_[HEAP, ARG0..$#_];

    # update status msg
    $h->{status} = 'Attacking ' . $dst->name . ' from ' . $src->name;

    # update attack dices
    foreach my $i ( 1 .. 3 ) {
        my $d = $attack->[$i-1] // 0;
        $h->{labels}{"attack_$i"}->configure(-image=>$h->{images}{"dice_$d"});
    }

    # update defence dices
    foreach my $i ( 1 .. 2 ) {
        my $d = $defence->[$i-1] // 0;
        $h->{labels}{"defence_$i"}->configure(-image=>$h->{images}{"dice_$d"});
    }

    # draw a line on the canvas
    my $c = $h->{canvas};
    state $i = 0;
    my ($zoomx, $zoomy) = @{ $h->{zoom} };
    my $x1 = $src->x * $zoomx; my $y1 = $src->y * $zoomy;
    my $x2 = $dst->x * $zoomx; my $y2 = $dst->y * $zoomy;
    $c->createLine(
        $x1, $y1, $x2, $y2,
        -arrow => 'last',
        -tags  => ['attack', "attack$i"],
        -fill  => 'yellow', #$h->{curplayer}->color,
        -width => 4,
    );
    my $srcid = $src->id;
    my $dstid = $dst->id;
    $c->raise('attack', 'all');
    $c->raise("country$srcid", 'attack');
    $c->idletasks;
    my $wait = $h->{curplayer}->type eq 'ai' ? $WAIT_CLEAN_AI : $WAIT_CLEAN_HUMAN;
    K->delay_set('_clean_attack' => $wait, $i);
    $i++;

    # update result labels
    my $ok  = $h->{images}{actcheck16};
    my $nok = $h->{images}{actcross16};
    my $nul = $h->{images}{empty16};
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
    $h->{labels}{attack}->configure(@ENOFF);
    $h->{buttons}{attack_redo}->configure(@ENOFF);
    $h->{buttons}{attack_done}->configure(@ENOFF);

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
    my $fakein  = $h->{fake_armies_in}{$id}  // 0;
    my $fakeout = $h->{fake_armies_out}{$id} // 0;
    my $armies  = ($country->armies // 0) + $fakein - $fakeout;

    # FIXME: change radius to reflect number of armies
    my ($radius, $fill_color, $text) = defined $owner
            ? (8, $owner->color, $armies)
            : (6,       'white', '');

    $radius += min(16,$armies-1)/2;
    my ($zoomx, $zoomy) = @{ $h->{zoom} };
    my $x = $country->x * $zoomx;
    my $y = $country->y * $zoomy;
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
    $h->{labels}{attack}->configure(@ENOFF);
    $h->{buttons}{attack_redo}->configure(@ENOFF);
    $h->{buttons}{attack_done}->configure(@ENOFF);

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
    $h->{labels}{move_armies}->configure(@ENON);
    $h->{buttons}{move_armies_done}->configure(@ENON);
    $h->{status} = 'Moving armies from...';
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
    $h->{buttons}{move_armies_done}->configure(@ENON);
    $h->{toplevel}->bind('<Key-Return>', $s->postback('_but_move_armies_done'));
    $h->{status} = 'Moving armies from...';
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
    $h->{labels}{place_armies}->configure(@ENON);

    # update status msg
    my $count = 0;
    $count += $_ for values %{ $h->{armies} };
    $h->{status} = "$count armies left to place";
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
    $h->{status} = "$nb armies left to place";
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
    $plabels->{ $old->name }->configure(-image=>$h->{images}{inactive}) if defined $old;
    $plabels->{ $new->name }->configure(-image=>$h->{images}{active});
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
        -image => $h->{images}{inactive},
    )->pack(@LEFT);
    $h->{labels}{players}{ $player->name } = $label;

    # associate tooltip
    my $tooltip = $player->name // '';
    given ($player->type) {
        when ('human') {
            $tooltip .= ' (human)';
        }

        when ('ai') {
            my $ai = $player->ai;
            my $difficulty  = $ai->difficulty;
            my $description = $ai->description;
            $tooltip .= " (computer - $difficulty)\n$description";
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
    $h->{labels}{players}{$name} ->configure( -image => $h->{images}{lost} );
    $h->{status} = "Player $name has lost";
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

    #-- various resources

    # load images
    # FIXME: this should be in a sub/method somewhere
    my $path = find_installed(__PACKAGE__);
    my (undef, $dirname, undef) = fileparse($path);
    $h->{images}{empty16}   = $top->Photo(-file=>"$dirname/icons/empty16.png");
    $h->{images}{lost}      = $top->Photo(-file=>"$dirname/icons/player-lost.png");
    $h->{images}{active}    = $top->Photo(-file=>"$dirname/icons/player-active.png");
    $h->{images}{inactive}  = $h->{images}{empty16};
    $h->{images}{"dice_$_"} = $top->Photo(-file=>"$dirname/icons/dice-$_.png") for 0..6;

    # load icons
    # code & artwork taken from Tk::ToolBar
    $path = "$dirname/icons/tk_icons";
    open my $fh, '<', $path or die "can't open '$path': $!";
    while (<$fh>) {
        chomp;
        last if /^#/; # skip rest of file
        my ($n, $d) = (split /:/)[0, 4];
        $h->{images}{$n} = $top->Photo(-data => $d);
    }
	close $fh;

    # ballon
    $h->{balloon} = $top->Balloon;


    #-- main frames
    my $fleft  = $top->Frame->pack(@LEFT,  @XFILL2);
    my $fright = $top->Frame->pack(@RIGHT, @FILL2);


    #-- frame for game state
    my $fgs = $fleft->Frame->pack(@TOP, @FILLX);
    $fgs->Label(-text=>'Game state: ')->pack(@LEFT);
    my $labp = $fgs->Label(-text=>'place armies', @ENOFF)->pack(@LEFT, @XFILL2);
    my $but_predo = $fgs->Button(
        -command => $s->postback('_but_place_armies_redo'),
        -image   => $h->{images}{actreload16},
        @ENOFF,
    )->pack(@LEFT);
    my $but_pdone = $fgs->Button(
        -command => $s->postback('_but_place_armies_done'),
        -image   => $h->{images}{navforward16},
        @ENOFF,
    )->pack(@LEFT);
    my $laba = $fgs->Label(-text=>'attack', @ENOFF)->pack(@LEFT, @XFILL2);
    my $but_aredo = $fgs->Button(
        -command => $s->postback('_but_attack_redo'),
        -image   => $h->{images}{actredo16},
        @ENOFF,
    )->pack(@LEFT);
    my $but_adone = $fgs->Button(
        -command => $s->postback('_but_attack_done'),
        -image   => $h->{images}{navforward16},
        @ENOFF,
    )->pack(@LEFT);
    my $labm = $fgs->Label(-text=>'move armies', @ENOFF)->pack(@LEFT, @XFILL2);
    my $but_mdone = $fgs->Button(
        -command => $s->postback('_but_move_armies_done'),
        -image   => $h->{images}{playstop16},
        @ENOFF,
    )->pack(@LEFT);
    $h->{labels}{place_armies} = $labp;
    $h->{labels}{attack}       = $laba;
    $h->{labels}{move_armies}  = $labm;
    $h->{buttons}{place_armies_redo} = $but_predo;
    $h->{buttons}{place_armies_done} = $but_pdone;
    $h->{buttons}{attack_redo}       = $but_aredo;
    $h->{buttons}{attack_done}       = $but_adone;
    $h->{buttons}{move_armies_done}  = $but_mdone;
    $h->{balloon}->attach($but_predo, -msg=>'undo all');
    $h->{balloon}->attach($but_pdone, -msg=>'ready for attack');
    $h->{balloon}->attach($but_aredo, -msg=>'attack again');
    $h->{balloon}->attach($but_adone, -msg=>'consolidate');
    $h->{balloon}->attach($but_mdone, -msg=>'turn finished');


    #-- canvas
    my $c = $fleft->Canvas->pack(@TOP,@XFILL2);
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
    my $fbot = $fleft->Frame->pack(@BOTTOM, @FILLX);
    $fbot->Label(
        -anchor       =>'w',
        -textvariable => \$h->{status},
    )->pack(@LEFT,@XFILLX, @PAD1);

    # label to display country pointed by mouse
    $h->{country}       = undef;
    $h->{country_label} = '';
    $fbot->Label(
        -anchor       => 'e',
        -textvariable => \$h->{country_label},
    )->pack(@RIGHT, @XFILLX, @PAD1);


     #-- players frame
    my $fpl = $fright->Frame->pack(@TOP);
    $fpl->Label(-text=>'Players')->pack(@TOP);
    my $fplist = $fpl->Frame->pack(@TOP);
    $h->{frames}{players} = $fplist;


    #-- dices frame
    my $fdice = $fright->Frame->pack(@TOP,@FILLX, -pady=>10);
    $fdice->Label(-text=>'Dice arena')->pack(@TOP,@FILLX);
    my $fd1 = $fdice->Frame->pack(@TOP,@FILL2);
    my $a1 = $fd1->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $a2 = $fd1->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $a3 = $fd1->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $fd3 = $fdice->Frame->pack(@TOP,@FILL2);
    my $r1 = $fd3->Label(
        -image => $h->{images}{empty16},
        -width => 38,
    )->pack(@LEFT);
    my $r2 = $fd3->Label(
        -image => $h->{images}{empty16},
        -width => 38,
    )->pack(@LEFT);
    my $fd2 = $fdice->Frame->pack(@TOP,@FILL2);
    my $d1 = $fd2->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $d2 = $fd2->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    $h->{labels}{attack_1}  = $a1;
    $h->{labels}{attack_2}  = $a2;
    $h->{labels}{attack_3}  = $a3;
    $h->{labels}{result_1}  = $r1;
    $h->{labels}{result_2}  = $r2;
    $h->{labels}{defence_1} = $d1;
    $h->{labels}{defence_2} = $d2;

    #-- trap close events
    $top->protocol( WM_DELETE_WINDOW => $s->postback('_window_close') );

    #-- other window
    Games::Risk::GUI::Cards->spawn({parent=>$top});
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
    $h->{labels}{attack}->configure(@ENOFF);
    $h->{buttons}{attack_redo}->configure(@ENOFF);
    $h->{buttons}{attack_done}->configure(@ENOFF);

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
    $h->{labels}{move_armies}->configure(@ENOFF);
    $h->{buttons}{move_armies_done}->configure(@ENOFF);
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
    $h->{labels}{place_armies}->configure(@ENOFF);
    $h->{buttons}{place_armies_redo}->configure(@ENOFF);
    $h->{buttons}{place_armies_done}->configure(@ENOFF);
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
    $h->{buttons}{place_armies_done}->configure(@ENOFF);
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
    $h->{status} = "$nb armies left to place";
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
    $h->{status} = 'Attacking ... from ' . $country->name;

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
    $h->{status} = 'Attacking from ...';

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
    $h->{status} = 'Attacking ' . $country->name . ' from ' . $h->{src}->name;

    # store opponent
    $h->{dst} = $country;

    # update gui to reflect new state
    $h->{canvas}->CanvasBind('<1>', undef);
    $h->{canvas}->CanvasBind('<3>', undef);
    $h->{buttons}{attack_done}->configure(@ENOFF);
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
    my $orig = Image::Resize->new($h->{map}->background);
    my $gd   = $orig->resize($neww, $newh, 0);

    # install this new image inplace of previous background
    my $img = $c->Photo( -data => encode_base64($gd->jpeg) );
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
    my ($zoomx, $zoomy) = @{ $h->{zoom} };
    $x /= $zoomx;
    $y /= $zoomy;

    # get greyscale pointed by mouse, this may die if moving too fast
    # outside of the canvas. we just need the 'red' component, since
    # green and blue will be the same.
    my $grey = 0;
    eval { ($grey) = $h->{greyscale}->get($x,$y) };
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
    $h->{status} = 'Moving armies from ...';

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
    return if $country->armies - ($h->{fake_armies_out}{$id}//0) == 1;

    # record move source
    $h->{src} = $country;

    # update status msg
    $h->{status} = 'Moving armies from ' . $country->name . ' to ...';

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
    $h->{status} = 'Moving armies from ' . $h->{src}->name . ' to ' .  $country->name;

    # store opponent
    $h->{dst} = $country;

    # update gui to reflect new state
    $h->{canvas}->CanvasBind('<1>', undef);
    $h->{canvas}->CanvasBind('<3>', undef);
    $h->{buttons}{move_armies_done}->configure(@ENOFF);
    $h->{toplevel}->bind('<Key-Return>', undef);

    # request user how many armies to move
    my $src = $h->{src};
    my $max = $src->armies - 1 - ($h->{fake_armies_out}{ $src->id }//0);
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
    return if $diff + ($h->{fake_armies_in}{$id}//0) < 0;   # negative count (free army move! :-) )

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
    $h->{buttons}{place_armies_redo}->configure(@ENON);
    $h->{toplevel}->bind('<Key-Escape>', $s->postback('_but_place_armies_redo'));

    # check if we're done
    my $nb = 0;
    $nb += $_ for values %{ $h->{armies} };
    $h->{status} = "$nb armies left to place";
    if ( $nb == 0 ) {
        # allow button next phase to be clicked
        $h->{buttons}{place_armies_done}->configure(@ENON);
        $h->{toplevel}->bind('<Key-Return>', $s->postback('_but_place_armies_done'));
        # forbid adding armies
        $h->{canvas}->CanvasBind('<1>', undef);
        $h->{canvas}->CanvasBind('<4>', undef);

    } else {
        # forbid button next phase to be clicked
        $h->{buttons}{place_armies_done}->configure(@ENOFF);
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
    $h->{status} = $nb ? "$nb armies left to place" : '';

    # tell controller that we've placed an army. controller will then
    # ask us to redraw the country.
    K->post('risk', 'initial_armies_placed', $country, 1);
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

__END__


=head1 NAME

Games::Risk::GUI::Board - board gui component



=head1 SYNOPSIS

    my $id = Games::Risk::GUI::Board->spawn(\%params);



=head1 DESCRIPTION

This class implements a poe session responsible for the board part of
the GUI. It features a map and various controls to drive the action.



=head1 METHODS


=head2 my $id = Games::Risk::GUI::Board->spawn( )



=begin quiet_pod_coverage

=item * K

=end quiet_pod_coverage



=head1 EVENTS

=head2 Events received


=over 4

=item * country_redraw( $country )

Force C<$country> to be redrawn: owner and number of armies.


=back



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

