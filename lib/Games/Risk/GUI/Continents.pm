#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI::Continents;

use 5.010;
use strict;
use warnings;

use Games::Risk::GUI::Constants;
use Games::Risk::Resources qw{ image };
use POE;

use constant K => $poe_kernel;


#--
# Constructor

#
# my $id = Games::Risk::GUI::Continents->spawn( \%params );
#
# create a new window to list continents and their associated bonus.
# refer to the embedded pod for an explanation of the supported options.
#
sub spawn {
    my ($class, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events - session mgmt
            _start               => \&_start,
            _stop                => sub { warn "gui-continents shutdown\n" },
            # public events
            shutdown             => \&shutdown,
            visibility_toggle    => \&visibility_toggle,
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events

#
# event: shutdown()
#
# kill current session. the toplevel window has already been destroyed.
#
sub shutdown {
    my $h = $_[HEAP];
    K->alias_remove('continents');
}


#
# visibility_toggle();
#
# Request window to be hidden / shown depending on its previous state.
#
sub visibility_toggle {
    my ($h) = $_[HEAP];

    my $top = $h->{toplevel};
    my $method = $top->state eq 'normal' ? 'withdraw' : 'deiconify';
    $top->$method;
}


# -- private events

#
# event: _start( \%opts );
#
# session initialization. \%params is received from spawn();
#
sub _start {
    my ($h, $s, $opts) = @_[HEAP, SESSION, ARG0];

    K->alias_set('continents');

    #-- create gui

    my $top = $opts->{parent}->Toplevel;
    $top->withdraw;           # window is hidden first
    $h->{toplevel} = $top;
    $top->title('Continents');
    $top->iconimage( image('icon-continents') );

    #- populate continents list
    my $map = Games::Risk->new->map;
    my @continents =
        sort {
             $b->bonus <=> $a->bonus ||
             $a->name  cmp $b->name
        }
        $map->continents;
    my $row = 0;
    my @opts = qw{ -anchor w };
    foreach my $c ( @continents ) {
        $top->Label(-text=>$c->name
        )->grid(-row=>$row,-column=>0,-sticky=>'w');
        $top->Label(-text=>$c->bonus)->grid(-row=>$row,-column=>1);
        $row++;
    }

    #- force window geometry
    $top->update;    # force redraw
    $top->resizable(0,0);

    #-- trap some events
    $top->protocol( WM_DELETE_WINDOW => $s->postback('visibility_toggle'));
    $top->bind('<F6>', $s->postback('visibility_toggle'));
}


1;

__END__


=head1 NAME

Games::Risk::GUI::Continents - continents listing



=head1 SYNOPSYS

    my $id = Games::Risk::GUI::Continents->spawn(%opts);



=head1 DESCRIPTION

C<GR::GUI::Continents> implements a POE session, creating a Tk window to
list the continents of the map and their associated bonus.



=head1 CLASS METHODS


=head2 my $id = Games::Risk::GUI::Continents->spawn( %opts );

Create a window listing the continents, and return the associated POE
session ID. One can pass the following options:

=over 4

=item parent => $mw

A Tk window that will be the parent of the toplevel window created. This
parameter is mandatory.


=back



=head1 PUBLIC EVENTS

The newly created POE session accepts the following events:


=over 4

=item * shutdown()

Kill current session. the toplevel window has already been destroyed.


=item * visibility_toggle()

Request window to be hidden / shown depending on its previous state.


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

