#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Map::Card;

use 5.010;
use strict;
use warnings;

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ country type } );


#--
# METHODS

# -- public methods

#
# $card->destroy;
#
# Remove all circular references of $card, to prevent memory leaks.
#
#sub DESTROY { say "destroy: $_[0]"; }
sub destroy {
    my ($self) = @_;
    $self->country(undef);
}




1;

__END__



=head1 NAME

Games::Risk::Map::Card - map card



=head1 SYNOPSIS

    my $card = Games::Risk::Map::Card->new(\%params);



=head1 DESCRIPTION

This module implements a map card, with all its characteristics.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $card = Games::Risk::Map::Card->new( \%params )

Create a new card. Mandatory param is C<type>, and there's an optional
param C<country>.


=back


=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Map::Card> objects:


=over 4

=item * country()

country corresponding to the card.


=item * type()

the type of the card: C<artillery>, C<cavalry>, C<infantery> or
C<wildcard>


=back


=head2 Methods

=over 4

=item * $card->destroy()

Remove all circular references of C<$card>, to prevent memory leaks.


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

