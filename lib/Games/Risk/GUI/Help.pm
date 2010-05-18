use 5.010;
use strict;
use warnings;

package Games::Risk::GUI::Help;
# ABSTRACT: help box

use POE                    qw{ Loop::Tk };
use Tk::Sugar;

use Games::Risk::I18N      qw{ T };
use Games::Risk::Resources qw{ image };

use constant K => $poe_kernel;


#--
# Constructor

#
# my $id = Games::Risk::GUI::Help->spawn( \%params );
#
# create a new window to list help info.
# refer to the embedded pod for an explanation of the supported options.
#
sub spawn {
    my (undef, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events - session mgmt
            _start               => \&_start,
            _stop                => sub { warn "gui-help-help shutdown\n" },
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
    #my $h = $_[HEAP];
    K->alias_remove('help');
}


#
# visibility_toggle();
#
# Request window to be hidden / shown depending on its previous state.
#
sub visibility_toggle {
    my ($h) = $_[HEAP];

    my $top = $h->{toplevel};
    my $method = ($top->state eq 'normal') ? 'withdraw' : 'deiconify'; # parens needed for xgettext
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

    K->alias_set('help');

    #-- create gui

    my $top = $opts->{parent}->Toplevel;
    $top->withdraw;           # window is hidden first
    $h->{toplevel} = $top;
    $top->title( T('Help') );
    $top->iconimage( image('icon-continents') );

    my @lines = split /\n/, <<'END_LINES';
Each player has territories marked with her color. In the mark there is a number indicating the
number of armies in that territory.
When it is your turn the first step is to distribute new armies. In the status bar at the bottom you can
see the additional armies you can deply. Each click on the territory you own will add one army to that
territory. The number of armies you can add in each turn is determined by the number of territories you
own and the continents you control when your turn arrives. In Addition you can get further armies by 
exchanging card for armies.

During this time you can click on the "undo all" button to start the distribution again.

Once you distributed all the armies you have to click on the "ready for attack" arrow.
Then select one of your territories to attack from and select one of the neigbouring enemy
territories to attack to. Throwing the die and calculating the results will be done automatically.

You can repeate this as many times as you want or as long as you have more than 1 armies in a territory.

When you kill all the armies in the neighbouring territory you will move some of your armies to the captured
territory. A pop-up window will let you pick the number of armies to move.
END_LINES
    my $row = 0;
    foreach my $c ( @lines ) {
        $top->Label(-text=>$c)->grid(-row=>$row,-column=>0,-sticky=>'w');
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


=head1 SYNOPSYS

    my $id = Games::Risk::GUI::Help->spawn(%opts);



=head1 DESCRIPTION

C<GR::GUI::Help> implements a POE session, creating a Tk window to
Help.



=head1 CLASS METHODS


=head2 my $id = Games::Risk::GUI::Continents->spawn( %opts );

Create a window listing information about the game, and return the associated POE
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


