#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Heap;

use 5.010;
use strict;
use warnings;

use List::Util qw{ shuffle };
use POE;
use aliased 'POE::Kernel' => 'K';

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ armies map _players } );

#--
# METHODS

# -- public methods

#
# my @players = $heap->players;
#
# Return the list of current players (Games::Risk::Player objects).
#
sub players {
    my ($self) = @_;
    return @{ $self->_players };
}



1;

__END__



=head1 NAME

Games::Risk::Heap - poe session heap for Games::Risk 



=head1 SYNOPSIS

    POE::Session->create(
        [...]
        heap => Games::Risk::Heap->new,
        [...]
    );



=head1 DESCRIPTION

This module implements a heap object, to be used in C<Games::Risk> POE
session. Furthermore, the non-event driven part of C<Games::Risk> will
be implemented as methods in this module.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $heap = Games::Risk::Heap->new

Create a new heap. No params needed.


=back


=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Heap> objects:


=over 4

=item * armies()

armies left to be placed.


=item * map()

the current C<Games::Risk::Map> object of the game.


=back


=head2 Public methods

=over 4


=item * my @players = $heap->players()

Return the C<Games::Risk::Player> objects of the current game.


=back


=begin quiet_pod_coverage

=item * K

=end quiet_pod_coverage



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

