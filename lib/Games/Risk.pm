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

use Games::Risk::Controller;
use Games::Risk::GUI::Board;
use List::Util qw{ shuffle };
use POE;
use aliased 'POE::Kernel' => 'K';

# Public variables of the module.
our $VERSION = '1.0.1';

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{
    armies curplayer dst got_card map move_in move_out nbdice src wait_for
    _players _players_active _players_turn_done _players_turn_todo
} );


#--
# CONSTRUCTOR

#
# my $game = Games::Risk->new( \%params );
#
# Create a new Games::Risk. This class implements a singleton scheme.
#
my $singleton;
sub new {
    # only one game at a time
    return $singleton if defined $singleton;

    my ($pkg, $args) = @_;

    # create object
    $singleton = {};
    bless $singleton, $pkg;

    # launch controller, and everything needed
    Games::Risk::Controller->spawn($singleton);

    # prettyfying tk app.
    # see http://www.perltk.org/index.php?option=com_content&task=view&id=43&Itemid=37
    $poe_main_window->optionAdd('*BorderWidth' => 1);

    Games::Risk::GUI::Board->spawn({toplevel=>$poe_main_window});
}


#--
# METHODS

# -- public methods

#
# $game->cards_reset;
#
# put back all cards given to players to the deck.
#
sub cards_reset {
    my ($self) = @_;
    my $map = $self->map;

    # return all distributed cards to the deck.
    foreach my $player ( $self->players ) {
        my @cards = $player->cards;
        $map->card_return($_) for @cards;
    }
}


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
# my @players = $game->players_active;
#
# Return the list of active players (Games::Risk::Player objects).
#
sub players_active {
    my ($self) = @_;
    return @{ $self->_players_active };
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
    Games::Risk->new;
    POE::Kernel->run;
    exit;



=head1 DESCRIPTION

Risk is a strategic turn-based board game. Players control armies, with
which they attempt to capture territories from other players. The goal
of the game is to control all the territories (C<conquer the world>)
through the elimination of the other players. Using area movement, Risk
ignores realistic limitations, such as the vast size of the world, and
the logistics of long campaigns.

This distribution implements a graphical interface for this game.

C<Games::Risk> itself tracks everything needed for a risk game. It is
also used as a heap for C<Games::Risk::Controller> POE session.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $game = Games::Risk->new

Create a new risk game. No params needed. Note: this class implements a
singleton scheme.


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

=item * $game->cards_reset;

Put back all cards given to players to the deck.


=item * $game->player_lost( $player )

Remove $player from the list of active players.


=item * my $player = $game->player_next()

Return the next player to play, or undef if the turn is over. Of course,
players that have lost will never be returned.


=item * my @players = $game->players()

Return the C<Games::Risk::Player> objects of the current game. Note that
some of those players may have already lost.


=item * my @players = $game->players_active;

Return the list of active players (Games::Risk::Player objects).


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

=item * better ais - DONE - 0.5.0: blitzkrieg ai, 0.5.1: hegemon ai

=item * country cards - DONE - 0.6.0

=item * continents bonus - DONE - 0.3.3

=item * continents bonus localized

=item * statistics

=item * prettier map coloring

=item * missions

=item * remove all the FIXMEs in the code :-)

=item * do-or-die mode (slanning's request)

=item * "attack trip" planning (slanning's request)

=item * other...

=back


However, the game is already totally playable by now: reinforcements,
continent bonus, country cards, different artificial intelligences...
Therefore, version 1.0.0 has been released with those basic
requirements. Except new features soon!



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
friends, you'll have an exciting time - much more than with this poor
electronic copy.

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

