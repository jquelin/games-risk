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
use Image::Size;
use Module::Util   qw{ find_installed };
use POE;
use Readonly;
use Tk;
use Tk::Balloon;
use Tk::JPEG;
use Tk::PNG;

use aliased 'POE::Kernel' => 'K';

my @TOP     = ( -side => 'top'    );
my @BOTTOM  = ( -side => 'bottom' );
my @LEFT    = ( -side => 'left'   );
my @RIGHT   = ( -side => 'right'  );

my @FILLX   = ( -fill => 'x'    );
my @FILL2   = ( -fill => 'both' );
my @XFILLX  = ( -expand => 1, -fill => 'x'    );
my @XFILL2  = ( -expand => 1, -fill => 'both' );

my @PAD1    = ( -padx => 1, -pady => 1);

my @ENON    = ( -state => 'normal' );
my @ENOFF   = ( -state => 'disabled' );


#--
# Constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            _start               => \&_onpriv_start,
            _stop                => sub { warn "gui-board shutdown\n" },
            # gui events
            _but_place_armies_done               => \&_ongui_but_place_armies_done,
            _but_place_armies_redo               => \&_ongui_but_place_armies_redo,
            _canvas_click_place_armies           => \&_ongui_canvas_click_place_armies,
            _canvas_click_place_armies_initial   => \&_ongui_canvas_click_place_armies_initial,
            _canvas_motion       => \&_ongui_canvas_motion,
            # public events
            chnum                => \&_onpriv_country_redraw,
            chown                => \&_onpriv_country_redraw,
            load_map             => \&_onpub_load_map,
            place_armies               => \&_onpub_place_armies,
            place_armies_initial       => \&_onpub_place_armies_initial,
            place_armies_initial_count => \&_onpub_place_armies_initial_count,
            player_active        => \&_onpub_player_active,
            player_add           => \&_onpub_player_add,
        },
    );
    return $session->ID;
}


#--
# Event handlers

# -- public events

#
# event: load_map( $map );
#
# load background and greyscale from $map. request countries to display
# their data.
#
sub _onpub_load_map {
    my ($h, $map) = @_[HEAP, ARG0];
    my $c = $h->{canvas};

    # remove everything
    $c->delete('all');

    # create background image
    my $img_path = $map->background;
    my ($width,$height) = imgsize($img_path);
    my $img = $c->Photo( -file=>$img_path );
    $c->configure(-width => $width, -height => $height);
    #use Data::Dumper; say Dumper($img);
    $c->createImage(0, 0, -anchor=>'nw', -image=>$img, -tags=>['background']);

    # create capitals
    foreach my $country ( $map->countries ) {
        # create text for country armies
        $c->createText(
            $country->x, $country->y+1,
            -fill => 'white',
            -tags => [ $country->id, 'text' ],
        );

        # update text values & oval
        K->yield('country_redraw', $country);
    }

    # load greyscale image
    $h->{greyscale} = $h->{toplevel}->Photo(-file=>$map->greyscale);


    # store map and say we're done
    $h->{map} = $map;
    K->post('risk', 'map_loaded');
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
    $c->CanvasBind( '<1>', $s->postback('_canvas_click_place_armies',  1) );
    $c->CanvasBind( '<3>', $s->postback('_canvas_click_place_armies', -1) );
    $c->CanvasBind( '<4>', $s->postback('_canvas_click_place_armies',  1) );
    $c->CanvasBind( '<5>', $s->postback('_canvas_click_place_armies', -1) );
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
    $c->CanvasBind( '<1>', $s->postback('_canvas_click_place_armies_initial') );
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


# -- private events

#
# Force C<$country> to be redrawn: owner and number of armies.
#
sub _onpriv_country_redraw {
    my ($h, $country) = @_[HEAP, ARG0];
    my $c = $h->{canvas};

    my $id    = $country->id;
    my $owner = $country->owner;
    my $fake  = $h->{fake_armies}{$id} // 0;

    # FIXME: change radius to reflect number of armies
    my ($radius, $fill_color, $text) = defined $owner
            ? (7, $owner->color, $country->armies + $fake )
            : (5,       'white', '');

    my $x = $country->x;
    my $y = $country->y;
    my $x1 = $x - $radius; my $x2 = $x + $radius;
    my $y1 = $y - $radius; my $y2 = $y + $radius;

    # update canvas
    $c->itemconfigure( "$id&&text", -text => $text);
    $c->delete( "$id&&circle" );
    $c->createOval(
        $x1, $y1, $x2, $y2,
        -fill    => $fill_color,
        -outline => 'black',
        -tags    => [ $country->id, 'circle' ],
    );
    $c->raise( "$id&&text", "$id&&circle" );
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

    # load images
    # FIXME: this should be in a sub/method somewhere
    my $path = find_installed(__PACKAGE__);
    my (undef, $dirname, undef) = fileparse($path);
    $h->{images}{inactive} = $top->Photo(-file=>"$dirname/icons/player-inactive.png");
    $h->{images}{active}   = $top->Photo(-file=>"$dirname/icons/player-active.png");

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

    # top frame
    my $ftop = $top->Frame->pack(@TOP, @XFILLX);

    # label to display country pointed by mouse
    $h->{country}       = undef;
    $h->{country_label} = '';
    $ftop->Label(
        -anchor       => 'e',
        -textvariable => \$h->{country_label},
    )->pack(@RIGHT, @XFILLX);

    # frame for players
    my $fpl = $ftop->Frame->pack(@LEFT);
    $fpl->Label(-text=>'Players: ')->pack(@LEFT);
    $h->{frames}{players} = $fpl;

    # frame for game state
    my $fgs = $top->Frame->pack(@TOP, @XFILL2);
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
    #$fgs->Button(-text=>'attack')->pack(@LEFT, @XFILL2);
    #$fgs->Button(-text=>'move armies')->pack(@LEFT, @XFILL2);
    $h->{labels}{place_armies} = $labp;
    $h->{labels}{attack}       = $laba;
    $h->{labels}{move_armies}  = $labm;
    $h->{buttons}{place_armies_redo} = $but_predo;
    $h->{buttons}{place_armies_done} = $but_pdone;
    $h->{balloon}->attach($but_predo, -msg=>'undo all');
    $h->{balloon}->attach($but_pdone, -msg=>'ready for attack');
    $h->{balloon}->attach($but_adone, -msg=>'consolidate');
    $h->{balloon}->attach($but_mdone, -msg=>'turn finished');

    # create canvas, removing class bindings
    my $c = $top->Canvas->pack;
    $h->{canvas} = $c;
    $c->CanvasBind( '<Motion>', [$s->postback('_canvas_motion'), Ev('x'), Ev('y')] );
    foreach my $button ( qw{ 4 5 6 7 } ) {
        $top->bind('Tk::Canvas', "<Button-$button>",       undef);
        $top->bind('Tk::Canvas', "<Shift-Button-$button>", undef);
    }
    foreach my $key ( qw{ Down End Home Left Next Prior Right Up } ) {
        $top->bind('Tk::Canvas', "<Key-$key>", undef);
        $top->bind('Tk::Canvas', "<Control-Key-$key>", undef);
    }

    # status bar
    $h->{status} = '';
    my $sb = $top->Frame->pack(@BOTTOM, @FILLX);
    $sb->Label(
        -anchor       =>'w',
        -textvariable => \$h->{status},
    )->pack(@RIGHT,@XFILLX, @PAD1);

    # say that we're done
    K->post('risk', 'window_created', 'board');
}

# -- gui events

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

    # request controller to update
    foreach my $id ( keys %{ $h->{fake_armies} } ) {
        next if $h->{fake_armies}{$id} == 0; # don't send null reinforcements
        my $country = $h->{map}->country_get($id);
        K->post('risk', 'armies_placed', $country, $h->{fake_armies}{$id});
    }
    $h->{armies} = {};
    $h->{armies_backup} = {};
    $h->{fake_armies} = {};
}


#
# event: _but_place_armies_redo();
#
# Called when user wants to restart from scratch reinforcements placing.
#
sub _ongui_but_place_armies_redo {
    my ($h, $s) = @_[HEAP, SESSION];

    foreach my $id ( keys %{ $h->{fake_armies} } ) {
        next if $h->{fake_armies}{$id} == 0;
        delete $h->{fake_armies}{$id};
        my $country = $h->{map}->country_get($id);
        K->yield('chnum', $country);
    }

    # forbid button next phase to be clicked
    $h->{buttons}{place_armies_done}->configure(@ENOFF);
    # allow adding armies
    $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_click_place_armies', 1) );
    $h->{canvas}->CanvasBind( '<4>', $s->postback('_canvas_click_place_armies', 1) );

    # reset initials
    my $nb = 0;
    foreach my $k ( keys %{ $h->{armies_backup} } ) {
        my $v = $h->{armies_backup}{$k};
        $h->{armies}{$k} = $v; # restore initial value
        $nb += $v;
    }
    $h->{fake_armies} = {};

    # updatee status
    $h->{status} = "$nb armies left to place";
}


#
# event: _canvas_motion( undef, [$canvas, $x, $y] );
#
# Called when mouse is moving over the $canvas at coords ($x,$y).
#
sub _ongui_canvas_motion {
    my ($h, $args) = @_[HEAP, ARG1];

    my (undef, $x,$y) = @$args; # first param is canvas

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
# event: _canvas_click_place_armies( [ $diff ] );
#
# Called when mouse click on the canvas during armies placement.
# Update "fake armies" to place $diff (may be negative) army on the
# current country.
#
sub _ongui_canvas_click_place_armies {
    my ($h, $s, $args) = @_[HEAP, SESSION, ARG0];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};
    return unless defined $country;
    my $id        = $country->id;
    my ($diff)    = @$args;

    # checks...
    return if $country->owner->name ne $curplayer->name; # country owner
    return if $diff + ($h->{fake_armies}{$id}//0) < 0;   # negative count (free army move! :-) )

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
    $h->{fake_armies}{ $country->id } += $diff;
    K->yield( 'chnum', $country );

    # allow redo button
    $h->{buttons}{place_armies_redo}->configure(@ENON);

    # check if we're done
    my $nb = 0;
    $nb += $_ for values %{ $h->{armies} };
    $h->{status} = "$nb armies left to place";
    if ( $nb == 0 ) {
        # allow button next phase to be clicked
        $h->{buttons}{place_armies_done}->configure(@ENON);
        # forbid adding armies
        $h->{canvas}->CanvasBind('<1>', undef);
        $h->{canvas}->CanvasBind('<4>', undef);

    } else {
        # forbid button next phase to be clicked
        $h->{buttons}{place_armies_done}->configure(@ENOFF);
        # allow adding armies
        $h->{canvas}->CanvasBind( '<1>', $s->postback('_canvas_click_place_armies', 1) );
        $h->{canvas}->CanvasBind( '<4>', $s->postback('_canvas_click_place_armies', 1) );
    }
}


#
# event: _canvas_click_place_armies_initial();
#
# Called when mouse click on the canvas during initial armies placement.
# Will request controller to place one army on the current country.
#
sub _ongui_canvas_click_place_armies_initial {
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

#--
# Subs

# -- private subs

sub _create_gui {
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
it under the same terms as Perl itself.

=cut

