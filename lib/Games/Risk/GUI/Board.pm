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

use Image::Size;
use POE;
use Readonly;
use Tk;
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
            _canvas_click_left   => \&_onpriv_canvas_click_left,
            # public events
            chown                => \&_onpub_country_redraw,
            load_map             => \&_onpub_load_map,
            player_add           => \&_onpub_player_add,
        },
    );
    return $session->ID;
}


#--
# Event handlers

# -- public events

#
# event: country_redraw( $country )
#
# Force C<$country> to be redrawn: owner and number of armies.
#
sub _onpub_country_redraw {
    my ($h, $country) = @_[HEAP, ARG0];
    my $c = $h->{canvas};

    my $id    = $country->id;
    my $owner = $country->owner;

    # FIXME: change radius to reflect number of armies
    my ($radius, $fill_color, $text) = defined $owner
            ? (7, $owner->color, $country->armies)
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

    K->post('risk', 'map_loaded');
}

sub _onpub_player_add {
    my ($h, $player) = @_[HEAP, ARG0];

    my $f = $h->{frames}{players};
    $f->Label(-width=>3, -bg => $player->color)->pack(@LEFT);
}


# -- private events

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

    # frame for players
    my $fpl = $top->Frame->pack(@TOP, @XFILL2);
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
    $c->CanvasBind('<1>', $s->postback('_canvas_click_left') );
    $h->{canvas} = $c;

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

sub _onpriv_canvas_click_left {
    my $h = $_[HEAP];
    # testing purposes
    #K->yield('load_map', '/home/jquelin/tmp/Risk/maps/france-jq.png');
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

