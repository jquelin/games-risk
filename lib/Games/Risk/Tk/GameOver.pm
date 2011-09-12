use 5.010;
use strict;
use warnings;

package Games::Risk::Tk::GameOver;
# ABSTRACT: window used when game is over

use Moose;
use MooseX::Has::Sugar;
use Tk::Sugar;

with 'Tk::Role::Dialog';

use Games::Risk::I18n   qw{ T };
use Games::Risk::Logger qw{ debug };

has winner => ( ro, isa=>'Games::Risk::Player', required );


# --

sub _build_title { T("Game over") }
sub _build_header { sprintf( T("%s won!"), $_[0]->winner->name ) }
sub _build_cancel { T('Close') }


#--

#
# $self->_build_gui( $frame );
#
# gui creation of the dialog content.
#
sub _build_gui {
    my ($self, $frame) = @_;
    my $top = $self->_toplevel;
    my $winner = $self->winner;

    $frame->Label(
        -text => ($winner->type eq 'human') ? # the ? should stay here for xgettext to understand it
              T("Congratulations, you won!\nMaybe the artificial intelligences were not that hard?")
            : T("Unfortunately, you lost...\nTry harder next time!")
    )->pack(top,pad20);

    #-- move window & enforce geometry
    $top->update;               # force redraw
    my ($wi,$he,$x,$y) = split /\D/, $top->parent->geometry;
    $x += int($wi / 3);
    $y += int($he / 3);
    $top->geometry("+$x+$y");
}


1;
__END__


=head1 SYNOPSYS

    Games::Risk::Tk::GameOver->new(
        parent => $top,
        winner => $player,
    );


=head1 DESCRIPTION

C<GR::Tk::GameOver> implements a Tk dialog to announce the winner of the
game.

