use 5.010;
use strict;
use warnings;

package Games::Risk::Country;
# ABSTRACT: map country

use Hash::NoRef;
use List::AllUtils qw{ any };
use Moose;
use MooseX::Aliases;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;

use Games::Risk::Logger qw{ debug };


# -- attributes

=attr name

The country name.

=attr continent

A L<Games::Risk::Continent> object in which the country is located.

=attr greyval

An integer between 1 and 254 corresponding at the grey (all RGB values
set to C<greyval()>) used to draw the country on the grey-scale map.

=attr id

Alias for C<greyval>.

=attr coordx

The x location of the country capital.

=attr coordy

The y location of the country capital.

=attr connections

A list of country ids that can be accessed from the country. Note that
it's not always reciprocical (connections can be one-way).

=cut

has name        => ( ro, isa=>'Str', required );
has continent   => ( ro, isa=>'Games::Risk::Continent', required, weak_ref );
has id          => ( ro, isa=>'Int', required, alias=>'greyval' );
has coordx      => ( ro, isa=>'Int', required );
has coordy      => ( ro, isa=>'Int', required );
has connections => ( ro, isa=>'ArrayRef[Int]', required, auto_deref );

=attr owner

A C<Games::Risk::Player> object currently owning the country.

=attr armies

Number of armies currently in the country.

=cut

has armies => ( rw, isa=>'Int' );
has owner  => ( rw, isa=>'Games::Risk::Player', weak_ref );



=method neighbours

    my @neighbours = $country->neighbours;

Return the list of C<$country>'s neighbours (L<Games::Risk::Country>
objects).

=method is_neighbour

    my $bool = $country->is_neighbour( $c );

Return true if C<$country> is a neighbour of country C<$c>, false
otherwise.

=cut

# a hash containing weak references (thanks Hash::NoRef) to prevent
# circular references to lock memory
has _neighbours => (
    ro, lazy_build,
    isa     =>'HashRef',
    traits  => [ 'Hash' ],
    handles => {
        neighbours   => 'values',
        is_neighbour => 'exists',
    },
);



# -- builders & finalizer

sub DEMOLISH { debug( "~country " . $_[0]->name ."\n" ); }

sub _build__neighbours {
    my $self = shift;
    my $map  = $self->continent->map;

    my %hash;
    tie %hash , 'Hash::NoRef';

    my @neighbours =
        map { $map->country_get($_) }
        $self->connections;
    @hash{ @neighbours } = @neighbours;

    return \%hash;
}



__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    DEMOLISH

=head1 DESCRIPTION

This module implements a map country, with all its characteristics. The
word country is a bit loose, since for some maps it can be either a
region, a suburb... or a planet!  :-)

