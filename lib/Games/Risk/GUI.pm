#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI;

use 5.010;
use strict;
use warnings;

use POE;
use Tk;

#--
# CLASS METHODS

# -- public methods

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            _resize        => \&_onpriv_resize,
            _start         => \&_onpriv_start,
            _stop          => sub { warn "GUI shutdown\n" },
            # public events
        },
    );
    return $session->ID;
}


#--
# EVENTS HANDLERS

# -- public events
# -- private events

sub _onpriv_resize {
    my ($k, $h) = @_[KERNEL, HEAP];
    $h->{canvas}->configure(-width=>500);
}


#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my ($k, $h, $s) = @_[KERNEL, HEAP, SESSION];

    $k->alias_set('gui');

    my $c = $poe_main_window->Canvas(-bg=>'peachpuff1')->pack;
    $c->CanvasBind('<1>', $s->postback('_resize') );
    $h->{canvas} = $c;

    $k->post('risk', 'gui_ready');
}


#--
# SUBROUTINES

# -- private subs

sub _create_gui {
}


1;

__END__



=head1 NAME

Games::Risk::GUI - main window



=head1 SYNOPSIS

    my $id = Games::Risk::GUI->new(\%params);



=head1 DESCRIPTION

This module is currently not used by C<Games::Risk>.



=head1 METHODS

=head2 my $id = Games::Risk->spawn( \%params )

This method will create a POE session responsible for the main window.
It will return the poe id of the session newly created.

You can tune the session by passing some arguments as a hash reference.
Currently, no params can be tuned.




=head1 EVENTS RECEIVED



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

