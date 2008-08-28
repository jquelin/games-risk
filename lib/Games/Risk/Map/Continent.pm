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

use Carp;

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ id name bonus } );


#--
# CLASS METHODS

# -- public methods

#
# my $continent = Games::Risk::Map::Continent->new( \%params );
#
# Constructor. New object can be tuned with %params:
#  - id:    continent unique id (mandatory)
#  - name:  continent name (mandatory)
#  - bonus: number of bonus armies when a player controls the continent (mandatory)
#
sub new {
    my ($pkg, $args) = @_;

    # check params
    my $id    = $args->{id}    or croak "missing param 'id'";
    my $name  = $args->{name}  or croak "missing param 'name'";
    my $bonus = $args->{bonus} or croak "missing param 'bonus'";

    # create object & fill it in
    my $self = bless {}, $pkg;
    $self->id   ( $id    );
    $self->name ( $name  );
    $self->bonus( $bonus );

    return $self;
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

Create a new continent. The recognized params are C<id>, C<name> and
C<bonus> (see below in C<Accessors> for a quick definition). Those
params are mandatory, and the constructor will die if they aren't
present.


=back


=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Map::Continent> objects:


=over 4

=item * id()

unique id assigned to the continent.


=item * name()

continent name.


=item * bonus()

number of bonus armies given when a player controls every country in the
continent.


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

