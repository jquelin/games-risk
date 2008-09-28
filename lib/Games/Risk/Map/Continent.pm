#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Map::Continent;

use 5.010;
use strict;
use warnings;

use List::MoreUtils qw{ all };

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ id bonus name _countries } );


#--
# METHODS

# -- public methods

#
# $continent->add_country( $country );
#
# Store C<$country> (a C<Games::Risk::Map::Country> object) as a country
# located within the continent.
#
sub add_country {
    my ($self, $country) = @_;
    my $countries = $self->_countries // [];
    push @$countries, $country;
    $self->_countries($countries);
}

#
# my @countries = $continent->countries;
#
# Return the list of countries located in $continent.
#
sub countries {
    my ($self) = @_;
    return @{ $self->_countries // [] };
}


#
# $continent->destroy;
#
# Remove all circular references of $continent, to prevent memory leaks.
#
#sub DESTROY { say "destroy: $_[0]"; }
sub destroy {
    my ($self) = @_;
    $self->_countries([]);
}


#
# my $p0wned = $continent->is_owned( $player );
#
# Return true if $player is the owner of all $continent's countries.
#
sub is_owned {
    my ($self, $player) = @_;

    return all { $_->owner eq $player } $self->countries;
}


1;

__END__



=head1 NAME

Games::Risk::Map::Continent - map continent



=head1 SYNOPSIS

    my $id = Games::Risk::Map::Continent->new(\%params);



=head1 DESCRIPTION

This module implements a map continent, with all its characteristics.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $player = Games::Risk::Map::Continent->new( \%params )

Create a new continent. Mandatory params are C<id>, C<name> and C<bonus>
(see below in C<Accessors> for a quick definition).


=back


=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Map::Continent> objects:


=over 4

=item * bonus()

number of bonus armies given when a player controls every country in the
continent.


=item * id()

unique id assigned to the continent.


=item * name()

continent name.

=back


=head2 Public methods

=over 4

=item * $continent->add_country( $country )

Store C<$country> (a C<Games::Risk::Map::Country> object) as a country
located within the C<$continent>.


=item * $continent->destroy()

Remove all circular references of C<$continent>, to prevent memory leaks.


=item * my @countries = $continent->countries()

Return the list of countries located in C<$continent>.


=item * my $p0wned = $continent->is_owned( $player )

Return true if C<$player> is the owner of all C<$continent>'s countries.


=back



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

