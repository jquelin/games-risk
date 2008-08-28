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

use Carp;

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ armies continent greyval id name owner x y } );



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
In order not to leak memory, the value stored should be weakened. This
applies both when passing a continent object to the constructor or when
changing it later on (but i don't see why one would want to change it
during the game).


=item * greyval()

an integer between 1 and 254 corresponding at the grey (all RGB values
set to C<greyval()>) used to draw the country on the grey-scale map.


=item * id()

internal unique id assigned to the country.


=item * name()

country name.


=item * owner()

a C<Games::Risk::Player> object currently owning the country. In order
not to leak memory, the value stored should be weakened. This applies
both when passing a player object to the constructor or when changing it
later on.


=item * x()

the x location of the country capital.


=item * y()

the y location of the country capital.


=back



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

