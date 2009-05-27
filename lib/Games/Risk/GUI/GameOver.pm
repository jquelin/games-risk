#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI::GameOver;

use 5.010;
use strict;
use warnings;

use Games::Risk::GUI::Constants;
use POE;
use Tk;
use Tk::Font;

use constant K => $poe_kernel;


#--
# Constructor

#
# my $id = Games::Risk::GUI::GameOver->spawn( \%params );
#
# create a new window to display who is the winner. refer to the
# embedded pod for an explanation of the supported options.
#
sub spawn {
    my ($class, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            _start       => \&_onpriv_start,
            _stop        => sub { warn "gui-gameover shutdown\n" },
            # gui events
            _but_close   => \&_onpriv_but_close,
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- private events

#
# event: _start( \%opts );
#
# session initialization. \%opts is received from spawn();
#
sub _onpriv_start {
    my ($h, $s, $opts) = @_[HEAP, SESSION, ARG0];

    K->alias_set('gameover');
    my $winner = $opts->{winner};
    my $name   = $winner->name;

    #-- create gui

    my $top  = $opts->{parent}->Toplevel(-title=>'Game over');
    $h->{toplevel} = $top;
    $top->withdraw;

    my $font = $top->Font(-size=>16);
    $top->Label(
        -bg   => $winner->color,
        -fg   => 'white',
        -font => $font,
        -text => "$name won!",
    )->pack(@TOP,@PAD20);
    $top->Label(
        -text => $winner->type eq 'human'
            ? 'Congratulations, you won! Maybe the artificial '
            . 'intelligences were not that hard?'
            : 'Unfortunately, you lost... Try harder next time!'
    )->pack(@TOP,@PAD20);
    $top->Button(
        -text    => 'Close',
        -command => $s->postback('_but_close'),
    )->pack(@TOP);


    #-- move window & enforce geometry
    $top->update;               # force redraw
    my ($wi,$he,$x,$y) = split /\D/, $top->parent->geometry;
    $x += int($wi / 3);
    $y += int($he / 3);
    $top->geometry("+$x+$y");
    $top->deiconify;


    #-- window bindings.
    $top->bind('<Key-Return>', $s->postback('_but_close'));
    $top->bind('<Key-space>', $s->postback('_but_close'));


    #-- trap some events
    $top->protocol( WM_DELETE_WINDOW => $s->postback('_but_close') );
}


# -- gui events

#
# event: _but_close()
#
# click on the close button, or if window has been closed.
#
sub _onpriv_but_close {
    my $h = $_[HEAP];
    $h->{toplevel}->destroy;
    delete $h->{toplevel};
    K->alias_remove('gameover');
}


1;

__END__


=head1 NAME

Games::Risk::GUI::GameOver - window used when game is over



=head1 SYNOPSYS

    my $id = Games::Risk::GUI::GameOver->spawn(%opts);



=head1 DESCRIPTION

C<GR::GUI::GameOver> implements a POE session, creating a Tk window to
announce the winner of the game. The window and asession are only used
once, then discarded.



=head1 CLASS METHODS


=head2 my $id = Games::Risk::GUI::GameOver->spawn( %opts );

Create a window, and return the associated POE session ID. One can pass
the following options:

=over 4

=item parent => $mw

A Tk window that will be the parent of the toplevel window created. This
parameter is mandatory.


=item winner => $player

The player that won the game. This parameter is mandatory.


=back




=head1 PUBLIC EVENTS

The newly created POE session does not accept nor fires any events.



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

