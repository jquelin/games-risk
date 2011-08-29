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

package Games::Risk::Country;
{
  $Games::Risk::Country::VERSION = '3.112410';
}
# ABSTRACT: map country

use List::MoreUtils qw{ any };

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ armies continent greyval name owner coordx coordy
    _neighbours } );


#--
# METHODS

# -- public methods

#
# $country->chown( $player );
#
# Change the owner of the $country to be $player. This implies updating
# cross-reference for previous owner and new one.
#
sub chown {
    my ($self, $player) = @_;

    # remove old owner
    my $previous = $self->owner;
    $previous->country_del($self) if defined $previous;

    # store new owner
    $self->owner($player);
    $player->country_add($self);
}


#
# $country->destroy;
#
# Remove all circular references of $country, to prevent memory leaks.
#
#sub DESTROY { say "destroy: $_[0]"; }
sub destroy {
    my ($self) = @_;
    $self->continent(undef);
    $self->owner(undef);
    $self->_neighbours([]);
}


#
# my $id = $country->id;
#
# For all intents & purposes, id is an alias to greyval
#
*id = \&greyval;


#
# my $bool = $country->is_neighbour($c);
#
# Return true if $country is a neighbour of country $c, false
# otherwise.
#
sub is_neighbour {
    my ($self, $c) = @_;
    return any { $_ eq $c } $self->neighbours;
}


#
# $country->neighbour_add( $c );
#
# Add $c to the list of $country's neighbours. This is not reciprocical.
#
sub neighbour_add {
    my ($self, $c) = @_;
    my @neighbours = $self->neighbours;
    push @neighbours, $c;
    $self->_neighbours( \@neighbours );
}


#
# my @neighbours = $country->neighbours;
#
# Return the list of the country's neighbours.
#
sub neighbours {
    my ($self) = @_;
    my $neighbours = $self->_neighbours // []; #//padre
    return @$neighbours;
}


1;



=pod

=head1 NAME

Games::Risk::Country - map country

=head1 VERSION

version 3.112410

=head1 SYNOPSIS

    my $country = Games::Risk::Country->new(\%params);

=head1 DESCRIPTION

This module implements a map country, with all its characteristics.

=head1 METHODS

=head2 Constructor

=over 4

=item * my $country = Games::Risk::Country->new( \%params )

Create a new country. Mandatory params are C<name>, C<continent>,
C<greyval>, C<x> and C<y> (see below in C<Accessors> section for a quick
definition of those params). Other attributes are optional, but can be
supplied anyway.

=back

=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Country> objects:

=over 4

=item * armies()

number of armies currently in the country.

=item * continent()

a C<Games::Risk::Continent> object in which the country is located.

=item * greyval()

an integer between 1 and 254 corresponding at the grey (all RGB values
set to C<greyval()>) used to draw the country on the grey-scale map.

=item * id()

alias for C<greyval()>.

=item * name()

country name.

=item * owner()

a C<Games::Risk::Player> object currently owning the country.

=item * coordx()

the x location of the country capital.

=item * coordy()

the y location of the country capital.

=back

=head2 Methods

=over 4

=item * $country->chown( $player )

Change the owner of the C<$country> to be C<$player>. This implies updating
cross-reference for previous owner and new one.

=item * $country->destroy()

Remove all circular references of C<$country>, to prevent memory leaks.

=item * my $bool = $country->is_neighbour( $c )

Return true if $country is a neighbour of country C<$c>, false
otherwise.

=item * my @neighbours = $country->neighbours()

Return the list of C<$country>'s neighbours.

=item * $country->neighbour_add( $c )

Add C<$c> to the list of C<$country>'s neighbours. This is not reciprocical.

=back

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


