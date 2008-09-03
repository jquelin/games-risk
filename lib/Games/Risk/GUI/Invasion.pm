#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI::Invasion;

use 5.010;
use strict;
use warnings;

use POE;
use Tk;

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

#
# my $id = Games::Risk::GUI::Invasion->spawn( \%params );
#
# create a new window to prompt for armies moved during invasion. refer
# to the embedded pod for an explanation of the supported options.
#
sub spawn {
    my ($class, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            _start     => \&_onpriv_start,
            # gui events
            _b_breakpoint_remove   => \&_on_b_breakpoint_remove,
            # public events
            move       => \&_onpub_move,
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events

#
# event: move( $src, $dst, $min );
#
# request how many armies to move from $src to $dst (minimum $dst,
# according to the number of attack dices).
#
sub _onpub_move {
    my ($h, $src, $dst, $min) = @_[HEAP, ARG0..$#_];

    #my $method = $h->{mw}->state eq 'normal' ? 'withdraw' : 'deiconify';
}


# -- private events

#
# event: _start( \%opts );
#
# session initialization. \%params is received from spawn();
#
sub _onpriv_start {
    my ($h, $s, $opts) = @_[HEAP, SESSION, ARG0];

    #-- create gui

    my $top = $opts->{parent}->Toplevel(-title => 'Country invasion');
    $top->withdraw;           # window is hidden first
    $h->{toplevel} = $top;

    $top->Label(-text=>'A country has been conquered!')->pack(@TOP,@XFILL2);

    #-- trap some events
    $top->protocol( WM_DELETE_WINDOW => sub{} );

    #-- enforce geometry
    $top->update;               # force redraw
    $top->resizable(0,0);
    my ($maxw,$maxh) = $top->geometry =~ /^(\d+)x(\d+)/;
    $top->maxsize($maxw,$maxh); # bug in resizable: minsize in effet but not maxsize
}


# -- gui events


1;

__END__


=head1 NAME

Games::Risk::GUI::Invasion - window to move armies



=head1 SYNOPSYS

    my $id = Games::Risk::GUI::Invasion->spawn(%opts);
    Poe::Kernel->post( $id, 'move', $src, $dst, $min );



=head1 DESCRIPTION

LBD::Breakpoints implements a POE session, creating a Tk window listing
the breakpoints set in a debugger session. The window can be hidden at
will.



=head1 CLASS METHODS


=head2 my $id = Games::Risk::GUI::Invasion->spawn( %opts );

Create a window requesting for amies move, and return the associated POE
session ID. One can pass the following options:

=over 4

=item parent => $mw

A Tk window that will be the parent of the toplevel window created. This
parameter is mandatory.


=back



=head1 PUBLIC EVENTS

The newly created POE session accepts the following events:


=over 4

=item move( $src, $dst, $min )

Show window and request how many armies to move from C<$src> to C<$dst>.
This number should be at least C<$min>, matching the number of dices
used for attack.


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

