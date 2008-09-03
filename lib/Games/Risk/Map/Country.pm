#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Map::Country;

use 5.010;
use strict;
use warnings;

use List::Util qw{ first };

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ armies continent greyval name owner x y
    _neighbours } );

# FIXME: resolve circular references for continents and owner


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
# my $id = $country->id;
#
# For all intents & purposes, id is an alias to greyval
#
*id = \&greyval;


#
# my $bool = $country->is_neighbour($id);
#
# Return true if $country is a neighbour of country with id $id, false
# otherwise.
#
sub is_neighbour {
    my ($self, $id) = @_;
    return first { $_ == $id } @{ $self->_neighbours };
}


1;

__END__



=head1 NAME

Games::Risk::Map::Country - map country



=head1 SYNOPSIS

    my $id = Games::Risk::Map::Country->new(\%params);



=head1 DESCRIPTION

This module implements a map country, with all its characteristics.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $player = Games::Risk::Map::Country->new( \%params )

Create a new country. Mandatory params are C<name>, C<continent>,
C<greyval>, C<x> and C<y> (see below in C<Accessors> section for a quick
definition of those params). Other attributes are optional, but can be
supplied anyway.


=back


=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Map::Country> objects:


=over 4

=item * armies()

number of armies currently in the country.


=item * continent()

a C<Games::Risk::Map::Continent> object in which the country is located.


=item * greyval()

an integer between 1 and 254 corresponding at the grey (all RGB values
set to C<greyval()>) used to draw the country on the grey-scale map.


=item * id()

alias for C<greyval()>.


=item * name()

country name.


=item * owner()

a C<Games::Risk::Player> object currently owning the country.


=item * x()

the x location of the country capital.


=item * y()

the y location of the country capital.


=back


=head2 Methods

=over 4

=item * $country->chown( $player )

Change the owner of the C<$country> to be C<$player>. This implies updating
cross-reference for previous owner and new one.


=item * my $bool = $country->is_neighbour( $id )

Return true if $country is a neighbour of country with id $id, false
otherwise.


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

