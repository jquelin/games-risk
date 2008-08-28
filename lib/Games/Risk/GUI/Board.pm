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
    my ($k, $h, $img_path) = @_[KERNEL, HEAP, ARG0];
    my $c = $h->{canvas};

    # remove everything
    $c->delete('all');

    # create background image
    my ($wi,$he) = imgsize($img_path);
    my $img = $c->Photo( -file=>$img_path );
    $c->configure(-width => $wi, -height => $he);
    #use Data::Dumper; say Dumper($img);
    $c->createImage(0, 0, -anchor=>'nw', -image=>$img, -tags=>['background']);
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

