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
use Tk;
use Tk::JPEG;
use Tk::PNG;

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
            load_map             => \&_onpub_load_map,
        },
    );
    return $session->ID;
}


#--
# Event handlers

# -- public events

sub _onpub_load_map {
    my ($k, $h, $map) = @_[KERNEL, HEAP, ARG0];
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
        my $x = $country->x;
        my $y = $country->y;
        my $owner = $country->owner;

        # create circle for country capital
        my $radius = 7; # FIXME: change radius to reflect number of armies
        my $x1 = $x - $radius; my $x2 = $x + $radius;
        my $y1 = $y - $radius; my $y2 = $y + $radius;

        my $fill_color = defined $owner ? $owner->color : 'white';
        my $line_color = 'black';
        $c->createOval(
            $x1, $y1, $x2, $y2,
            -fill    => $fill_color,
            -outline => $line_color,
            -tags    => [ $country->id, $country->name, 'circle' ],
        );

        # create text for country armies
        my $text       = defined $owner ? $owner->armies : '';
        my $text_color = defined $owner ? 'white' : 'black';
        $c->createText(
            $x, $y+1,
            -text => '0',
            -fill => $text_color,
            -tags => [ $country->id, $country->name, 'text' ],
        );
    }
}


# -- private events

#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my ($k, $h, $s, $args) = @_[KERNEL, HEAP, SESSION, ARG0];

    $k->alias_set('board');

    # create toplevel
    my $top = $h->{toplevel} = $args->{toplevel};
    my $c = $top->Canvas->pack;
    $c->CanvasBind('<1>', $s->postback('_canvas_click_left') );
    $h->{canvas} = $c;

    # say that we're done
    $k->post('risk', 'board_ready');
}

# -- gui events

sub _onpriv_canvas_click_left {
    my ($k, $h) = @_[KERNEL, HEAP];
    # testing purposes
    #$k->yield('load_map', '/home/jquelin/tmp/Risk/maps/france-jq.png');
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



=head1 EVENTS RECEIVED



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

