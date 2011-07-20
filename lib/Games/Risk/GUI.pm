use 5.010;
use strict;
use warnings;

package Games::Risk::GUI;
# ABSTRACT: gui multiplexer poe session

use POE qw{ Loop::Tk };
use MooseX::POE;
use Readonly;

use Games::Risk::GUI::Board;
use Games::Risk::GUI::Startup;

Readonly my $K  => $poe_kernel;


# -- initialization

sub START {
    # prettyfying tk app.
    # see http://www.perltk.org/index.php?option=com_content&task=view&id=43&Itemid=37
    $poe_main_window->optionAdd('*BorderWidth' => 1);

    # create main window
    Games::Risk::GUI::Startup->spawn({toplevel=>$poe_main_window});

    # register aliases
    $K->alias_set('gui');
}

sub STOP { warn "GUI shutdown\n"; }


# -- public events

#
# this event will track all the events not caught specifically, and
# forward them to all the gui sessions.
#
event _default => sub {
    my ($sender, $event, $args) = @_[SENDER, ARG0, ARG1];
    return if $sender eq $poe_kernel;
    $K->post($_, $event, @$args) foreach qw{ board cards continents gameover move-armies };
};


=event new_game

=cut

event new_game => sub {
    my $args = $_[ARG0];
    my $mw = $poe_main_window->Toplevel;
    Games::Risk::GUI::Board->spawn( { toplevel=>$mw, %$args } );
};


1;

__END__

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

This poe session answers to the C<gui> L<POE> alias.


