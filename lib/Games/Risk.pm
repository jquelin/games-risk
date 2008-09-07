#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk;

use 5.010;
use strict;
use warnings;

use List::Util qw{ shuffle };
use POE;
use aliased 'POE::Kernel' => 'K';

# Public variables of the module.
our $VERSION = '0.5.0';

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{
    armies curplayer dst map move_in move_out nbdice src wait_for
    _players _players_active _players_turn_done _players_turn_todo
} );

#--
# METHODS

# -- public methods

#
# $game->player_lost( $player );
#
# Remove a player from the list of active players.
#
sub player_lost {
    my ($self, $player) = @_;

    # remove from current turn
    my @done = grep { $_ ne $player } @{ $self->_players_turn_done };
    my @todo = grep { $_ ne $player } @{ $self->_players_turn_todo };
    $self->_players_turn_done( \@done );
    $self->_players_turn_todo( \@todo );

    # remove from active list
    my @active = grep { $_ ne $player } @{ $self->_players_active };
    $self->_players_active( \@active );
}


#
# my $player = $game->player_next;
#
# Return the next player to play, or undef if the turn is over.
#
sub player_next {
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
# my @players = $game->players;
#
# Return the list of current players (Games::Risk::Player objects).
# Note that some of those players may have already lost.
#
sub players {
    my ($self) = @_;
    return @{ $self->_players };
}


#
# $game->players_reset;
#
# Mark all players to be in "turn to do". Typically called during
# initial army placing, or real game start.
#
sub players_reset {
    my ($self) = @_;

    my @players = @{ $self->_players_active };
    $self->_players_turn_done([]);
    $self->_players_turn_todo( \@players );
}




1;

__END__



=head1 NAME

Games::Risk - classical 'risk' board game



=head1 SYNOPSIS

    use Games::Risk;
    Games::Risk->start;
    POE::Kernel->run;
    exit;



=head1 DESCRIPTION

This module tracks everything needed for a risk game. It is also used as
a heap for C<Games::Risk::Controller> POE session.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $game = Games::Risk->new

Create a new risk game. No params needed.


=back


=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk> objects:


=over 4

=item * armies()

armies left to be placed.


=item * map()

the current C<Games::Risk::Map> object of the game.


=back


=head2 Public methods

=over 4


=item * my @players = $game->players()

Return the C<Games::Risk::Player> objects of the current game. Note that
some of those players may have already lost.


=item * $game->player_lost( $player )

Remove $player from the list of active players.


=item * my $player = $game->player_next()

Return the next player to play, or undef if the turn is over. Of course,
players that have lost will never be returned.


=item * $game->players_reset()

Mark all players to be in "turn to do", effectively marking them as
still in play. Typically called during initial army placing, or real
game start.


=back


=begin quiet_pod_coverage

=item * K

=end quiet_pod_coverage



=head1 TODO

This is a work in progress. While there are steady improvements, here's
a rough list (with no order implied whatsoever) of what you can expect
in the future for C<Games::Risk>:

=over 4

=item * screen to customize the new game to be played

=item * config save / restore

=item * saving / loading game

=item * network play

=item * maps theming

=item * i18n

=item * better ais

=item * country cards

=item * continents bonus, maybe localized?

=item * statistics

=item * prettier map coloring

=item * missions

=item * remove all the FIXMEs in the code :-)

=item * other...

=back



=head1 BUGS

Please report any bugs or feature requests to C<bug-games-risk at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Games-Risk>.  I will be
notified, and then you'll automatically be notified of progress on your
bug as I make changes.



=head1 SEE ALSO

You can find more information on the classical C<risk> game on wikipedia
at L<http://en.wikipedia.org/wiki/Risk_game>.

You might also want to check jRisk, a java-based implementation of Risk,
which inspired me quite a lot.


You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Games-Risk>


=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Games-Risk>


=item * Open bugs

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Games-Risk>


=back



=head1 ACKNOWLEDGEMENTS

I definitely recommend you to buy a C<risk> board game and play with
friends, you'll have an exciting time!

Some ideas  & artwork taken from project C<jrisk>, available at
L<http://risk.sourceforge.net/>. Others (ideas & artwork once again)
taken from teg, available at L<http://teg.sourceforge.net/>



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.


=cut

