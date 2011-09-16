use 5.010;
use strict;
use warnings;

package Games::Risk::Card;
# ABSTRACT: map card

use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;

use Games::Risk::Logger qw{ debug };
use Games::Risk::Types;


# -- attributes

=attr country

Country corresponding to the card (L<Map::Games::Risk::Country> object).

=attr type

Type of the card: C<artillery>, C<cavalry>, C<infantery> or C<joker>.

=cut

has type    => ( ro, isa=>'CardType', required );
has country => ( rw, isa=>'Games::Risk::Country', weak_ref );


# -- builders / finishers

sub DEMOLISH {
    my $self = shift;
    my $type = $self->type;
    my $country = $self->country;
    my $name = $country ? $country->name : '';
    debug( "~card: $type ($name)\n" );
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    DEMOLISH


=head1 DESCRIPTION

This module implements a map card, with all its characteristics.

