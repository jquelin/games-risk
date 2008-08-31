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

Readonly my @TOP     => ( -side => 'top'    );
Readonly my @BOTTOM  => ( -side => 'bottom' );
Readonly my @LEFT    => ( -side => 'left'   );
Readonly my @RIGHT   => ( -side => 'right'  );

Readonly my @FILLX   => ( -fill => 'x'    );
Readonly my @FILL2   => ( -fill => 'both' );
Readonly my @XFILLX  => ( -expand => 1, -fill => 'x'    );
Readonly my @XFILL2  => ( -expand => 1, -fill => 'both' );

Readonly my @PAD1    => ( -padx => 1, -pady => 1);


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
            _canvas_click_place_initial_armies   => \&_ongui_canvas_click_place_initial_armies,
            _canvas_motion       => \&_ongui_canvas_motion,
            # public events
            chnum                => \&_onpriv_country_redraw,
            chown                => \&_onpriv_country_redraw,
            load_map             => \&_onpub_load_map,
            place_armies_inital        => \&_onpub_place_armies,
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
# event: place_armies_initial( $how [, $continent] );
#
# request user to place $how much armies on her countries (maybe within
# $continent if supplied).
#
sub _onpub_place_armies_initial {
    my ($h, $s, $how, $continent) = @_[HEAP, SESSION, ARG0, ARG1];

    my $name = defined $continent ? $continent->name : 'free';
    $h->{armies}{$name} += $how;


    my $c = $h->{canvas};
    $c->CanvasBind('<1>', $s->postback('_canvas_click_place_initial_armies', 1) );
    $c->CanvasBind('<2>', $s->postback('_canvas_click_place_initial_armies', -1) );

    # update status msg
    my $nb = 0;
    $nb += $_ for values %{ $h->{armies} };
    $h->{status} = "$nb armies left to place";
}


#
# event: place_armies_initial_count( $how );
#
# request user to place $how much armies on her countries. this is
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
    #my $fgs = $top->Frame->pack(@TOP, @XFILL2);
    #$fgs->Label(-text=>'Game state: ')->pack(@LEFT);
    #$fgs->Button(-text=>'place armies')->pack(@LEFT, @XFILL2);
    #$fgs->Button(-text=>'attack')->pack(@LEFT, @XFILL2);
    #$fgs->Button(-text=>'move armies')->pack(@LEFT, @XFILL2);

    # create canvas
    my $c = $top->Canvas->pack;
    $c->CanvasBind('<Motion>', [$s->postback('_canvas_motion'), Ev('x'), Ev('y')] );
    $h->{canvas} = $c;

    # status bar
    $h->{status} = '';
    my $sb = $top->Frame->pack(@BOTTOM, @FILLX);
    $sb->Label(
        -anchor       =>'w',
        -textvariable => \$h->{status},
    )->pack(@RIGHT,@XFILLX, @PAD1);

    # ballon
    $h->{balloon} = $top->Balloon;

    # images
    # FIXME: this should be in a sub/method somewhere
    my $path = find_installed(__PACKAGE__);
    my (undef, $dirname, undef) = fileparse($path);
    $h->{images}{inactive} = $top->Photo(-file=>"$dirname/icons/player-inactive.png");
    $h->{images}{active}   = $top->Photo(-file=>"$dirname/icons/player-active.png");

    # say that we're done
    K->post('risk', 'window_created', 'board');
}

# -- gui events

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


sub _ongui_canvas_click_place_initial_armies {
    my ($h, $args) = @_[HEAP, ARG0];

    my $curplayer = $h->{curplayer};
    my $country   = $h->{country};

    # check country owner
    return if $country->owner->name ne $curplayer->name;

    # 
    my ($diff) = @$args;
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

    # check if we're done
    # FIXME: >=2 armies to place should have a validation
    my $nb = 0;
    $nb += $_ for values %{ $h->{armies} };
    if ( $nb == 0 ) {
        $h->{status} = '';
        my $c = $h->{canvas};
        $c->CanvasBind('<1>', undef);
        $c->CanvasBind('<2>', undef);

        foreach my $id ( keys %{ $h->{fake_armies} } ) {
            my $country = $h->{map}->country_get($id);
            K->post('risk', 'armies_placed', $country, $h->{fake_armies}{$id});
        }
        $h->{fake_armies} = {};
    } else {
        $h->{status} = "$nb armies left to place";
    }
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

