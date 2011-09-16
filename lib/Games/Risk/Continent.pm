use 5.010;
use strict;
use warnings;

package Games::Risk::Continent;
# ABSTRACT: continent object

use List::MoreUtils qw{ all };
use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;

use Games::Risk::Logger qw{ debug };


# -- attributes

=attr id

Unique id assigned to the continent.

=attr bonus

Number of bonus armies given when a player controls every country in the
continent.

=attr name

Continent name.

=attr color

Color of the continent to flash it.

=attr map

Reference to the parent map (weak ref to a L<Games::Risk::Map> object).

=attr countries

The L<Games::Risk::Country> objects belonging to this continent.

=cut

has id    => ( ro, isa=>'Int', required );
has name  => ( ro, isa=>'Str', required );
has bonus => ( ro, isa=>'Int', required );
has color => ( ro, isa=>'Str', required );
has map   => ( ro, isa=>'Games::Risk::Map', required, weak_ref );
has countries => ( rw, auto_deref, isa=>'ArrayRef[Games::Risk::Country]' );


# -- finalizer

sub DEMOLISH { debug( "~continent " . $_[0]->name ."\n" ); }


# -- public methods

=method is_owned

    my $p0wned = $continent->is_owned( $player );

Return true if C<$player> is the owner of all C<$continent>'s countries.

=cut

sub is_owned {
    my ($self, $player) = @_;

    return all { $_->owner eq $player } $self->countries;
}


__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    DEMOLISH

=head1 DESCRIPTION

This module implements a map continent, with all its characteristics.
The word continent is a bit loose, since for some maps it can be either
a region, a suburb... or a planet! :-)

