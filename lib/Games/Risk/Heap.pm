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
__PACKAGE__->mk_accessors( qw{ armies curplayer map wait_for _players _players_turn_done _players_turn_todo } );

#--
# METHODS

# -- public methods

#
# my @players = $heap->players;
#
# Return the list of current players (Games::Risk::Player objects).
# Note that some of those players may have already lost.
#
sub players {
    my ($self) = @_;
    return @{ $self->_players };
}


#
# my $player = $heap->players_next;
#
# Return the next player to play, or undef if the turn is over.
#
sub players_next {
    my ($self) = @_;

    my @done = @{ $self->_players_turn_done };
    my @todo = @{ $self->_players_turn_todo };
    my $next = shift @todo;

    if ( defined $next ) {
        push @done, $next;
    } else {
        # turn is finished, start anew
        @todo = @done;
        @done = ();
    }

    # store new state
    $self->_players_turn_done( \@done );
    $self->_players_turn_todo( \@todo );

    return $next;
}


#
# $heap->players_reset;
#
# Mark all players to be in "turn to do". Typically called during
# initial army placing, or real game start.
#
sub players_reset {
    my ($self) = @_;
    my @players = $self->players;
    $self->_players_turn_done([]);
    $self->_players_turn_todo( \@players );
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

Return the C<Games::Risk::Player> objects of the current game. Note that
some of those players may have already lost.


=item * my $player = $heap->players_next()

Return the next player to play, or undef if the turn is over. Of course,
players that have lost will never be returned.


=item * $heap->players_reset()

Mark all players to be in "turn to do", effectively marking them as
still in play. Typically called during initial army placing, or real
game start.


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

