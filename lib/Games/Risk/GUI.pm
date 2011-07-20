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

package Games::Risk::GUI;
BEGIN {
  $Games::Risk::GUI::VERSION = '3.112010';
}
# ABSTRACT: gui multiplexer poe session

use POE qw{ Loop::Tk };

use Games::Risk::GUI::Board;
use Games::Risk::GUI::Startup;

use constant K => $poe_kernel;

#--
# CLASS METHODS

# -- public methods

sub spawn {
    my (undef, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            _start         => \&_onpriv_start,
            _stop          => sub { warn "GUI shutdown\n" },
            # public events
            _default       => \&_onpub_default,
            new_game       => \&_onpub_new_game,
        },
    );
    return $session->ID;
}


#--
# EVENTS HANDLERS

# -- public events

sub _onpub_default {
    my ($sender, $event, $args) = @_[SENDER, ARG0, ARG1];
    return if $sender eq $poe_kernel;
    K->post($_, $event, @$args) foreach qw{ board cards continents gameover move-armies };
}

sub _onpub_new_game {
    my $args = $_[ARG0];
    my $mw = $poe_main_window->Toplevel;
    Games::Risk::GUI::Board->spawn( { toplevel=>$mw, %$args } );
}


# -- private events

#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    # prettyfying tk app.
    # see http://www.perltk.org/index.php?option=com_content&task=view&id=43&Itemid=37
    $poe_main_window->optionAdd('*BorderWidth' => 1);

    # create main window
    Games::Risk::GUI::Startup->spawn({toplevel=>$poe_main_window});

    # register aliases
    K->alias_set('gui');
}



1;



=pod

=head1 NAME

Games::Risk::GUI - gui multiplexer poe session

=head1 VERSION

version 3.112010

=head1 SYNOPSIS

    my $id = Games::Risk::GUI->spawn(\%params);

=head1 DESCRIPTION

C<Games::Risk> uses various windows to display the game: the board of
course, but also the window displaying the cards owned by the player,
and some others.

Depending on the event, the controller needs to send events to a given
window, or even to more than one. But it is clearly not the controller's
job to know how the GUI works!

Therefore, C<Games::Risk::GUI> is a poe session that will receive all
the events fired by the controller, and forward them to the other
windows. Of course, the controller now fires its events only to the
C<Games::Risk::GUI> session.

This poe session will have various aliases: the player's name, the
player object stringified, and finally the alias C<gui>.

=head1 METHODS

=head2 my $id = Games::Risk->spawn( \%params )

This method will create a POE session responsible for multiplexing the
events received from the controller to the various windows.

It will return the poe id of the session newly created.

You can tune the session by passing some arguments as a hash reference:

=over 4

=item * player => $player

The human C<$player> that will control the GUI.

=back

=head1 EVENTS RECEIVED

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


