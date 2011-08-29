#
# This file is part of Games-Risk
#
# This software is Copyright (c) 2008 by Jerome Quelin.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#
use 5.010;
use strict;
use warnings;

package Games::Risk::GUI::GameOver;
{
  $Games::Risk::GUI::GameOver::VERSION = '3.112410';
}
# ABSTRACT: window used when game is over

use POE qw{ Loop::Tk };
use Tk;
use Tk::Font;
use Tk::Sugar;

use Games::Risk::I18n  qw{ T };
use Games::Risk::Utils qw{ debug };

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
    my (undef, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            _start       => \&_onpriv_start,
            _stop        => sub { debug( "gui-gameover shutdown\n" ) },
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

    my $top  = $opts->{parent}->Toplevel(-title=>T('Game over'));
    $h->{toplevel} = $top;
    $top->withdraw;

    my $font = $top->Font(-size=>16);
    $top->Label(
        -bg   => $winner->color,
        -fg   => 'white',
        -font => $font,
        -text => sprintf( T("%s won!"), $name ),
    )->pack(top,pad20);
    $top->Label(
        -text => ($winner->type eq 'human') ? # the ? should stay here for xgettext to understand it
              T("Congratulations, you won!\nMaybe the artificial intelligences were not that hard?")
            : T("Unfortunately, you lost...\nTry harder next time!")
    )->pack(top,pad20);
    $top->Button(
        -text    => T('Close'),
        -command => $s->postback('_but_close'),
    )->pack(top);


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



=pod

=head1 NAME

Games::Risk::GUI::GameOver - window used when game is over

=head1 VERSION

version 3.112410

=head1 DESCRIPTION

C<GR::GUI::GameOver> implements a POE session, creating a Tk window to
announce the winner of the game. The window and asession are only used
once, then discarded.

=head1 SYNOPSYS

    my $id = Games::Risk::GUI::GameOver->spawn(%opts);

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

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__


