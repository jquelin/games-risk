use 5.010;
use strict;
use warnings;

package Games::Risk::Deck;
# ABSTRACT: pandemic card deck

use Moose 0.92;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;

use Games::Risk::Logger qw{ debug };


# -- builders / finishers

sub DEMOLISH { debug( "~deck: $_[0]\n" ); }


# -- accessors

=attr cards

The set of L<Games::Risk::Card>s hold in the deck.

=method get

    my $card = $deck->get;

Get the next C<$card> in the deck.

=method return

    $deck->return( $card ).

Return C<$card> to the deck of cards.

=cut

has cards => (
    ro, required, auto_deref,
    traits     => ['Array'],
    isa        => 'ArrayRef[Games::Risk::Card]',
    handles => {
#        clear   => 'clear',
#        count   => 'count',
        get     => 'shift',
        return  => 'push',
    },
);

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=for Pod::Coverage
    DEMOLISH

=head1 DESCRIPTION

A L<Games::Risk::Deck> contains a set of L<Games::Risk::Card>, with
methods to handle this set.

