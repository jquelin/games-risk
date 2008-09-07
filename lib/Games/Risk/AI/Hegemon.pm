#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::AI::Hegemon;

use 5.010;
use strict;
use warnings;

use List::MoreUtils qw{ all };

use base qw{ Games::Risk::AI };

#--
# METHODS

# -- public methods

#
# my ($action, [$from, $country]) = $ai->attack;
#
# See pod in Games::Risk::AI for information on the goal of this method.
#
# This implementation never attacks anything, it ends its attack turn as soon
# as it begins. Therefore, it always returns ('attack_end', undef, undef).
#
sub attack {
    my ($self) = @_;
    my $player = $self->player;

    # find first possible attack
    my ($src, $dst);
    COUNTRY:
    foreach my $country ( shuffle $player->countries )  {
        # don't attack unless there's somehow a chance to win
        next COUNTRY if $country->armies < 4;

        NEIGHBOUR:
        foreach my $neighbour ( shuffle $country->neighbours ) {
            # don't attack ourself
            next NEIGHBOUR if $neighbour->owner eq $player;
            return ('attack', $country, $neighbour);
        }
    }

    # hum. we don't have that much choice, do we?
    return ('attack_end', undef, undef);
}


#
# my $nb = $ai->attack_move($src, $dst, $min);
#
# See pod in Games::Risk::AI for information on the goal of this method.
#
# This implementation always move the maximum possible from $src to
# $dst.
#
sub attack_move {
    my ($self, $src, $dst, $min) = @_;
    return $src->armies - 1;
}


#
# my $difficulty = $ai->difficulty;
#
# Return a difficulty level for the ai.
#
sub difficulty { return 'hard' }


#
# my @where = $ai->move_armies;
#
# See pod in Games::Risk::AI for information on the goal of this method.
#
# This implementation will not move any armies at all.
#
sub move_armies {
    my ($self) = @_;
    return;
}


#
# my @where = $ai->place_armies($nb, [$continent]);
#
# See pod in Games::Risk::AI for information on the goal of this method.
#
# This implementation will place the armies randomly on the continent owned by
# the AI, maybe restricted by $continent if it is specified.
#
sub place_armies {
    my ($self, $nb, $continent) = @_;
    my $me   = $self->player;
    my $game = $self->game;
    my $map  = $game->map;

    my @continents   = $map->continents;
    my @my_countries = $me->countries;

    # FIXME: restrict to continent if strict placing
    #my @countries = defined $continent
    #    ? grep { $_->continent->id == $continent } $player->countries
    #    : $player->countries;

    # 1- find a country that can be used as an attack base.
    my $where = $self->_country_to_attack_from_small;

    # 2- check if we can block another player from gaining a continent.
    # this takes precedence over basic attack as defined in 1-
    my $block = $self->_country_to_block_continent;
    $where    = $block if defined $block;

    # 3- even more urgent: try to remove a continent from the greedy
    # hands of another player. ai will try to free continent as far as 4
    # countries! prefer to free closer continents - if range equals,
    # decision is taken based on continent worth.
    my $free = $self->_country_to_free_continent;
    $where   = $free if defined $free;

    # 4- another good opportunity: completely crushing a weak enemy
    my $weak = $self->_country_to_crush_weak_enemy;
    $where   = $weak if defined $weak;


    # assign all of our armies in one country
    return ( [ $where, $nb ] );
}


# -- private methods

#
# my $bool = $ai->_almost_owned( $player, $continent );
#
# Return true if $continent is almost (as in "all countries but 2")
# owned by $player.
#
sub _almost_owned {
    my ($self, $player, $continent) = @_;

    my @countries = $continent->countries;
    my @owned     = grep { $_->owner eq $player } @countries;

    return scalar(@owner) >= scalar(@countries) - 2;
}


#
# my @continents = $ai->_continents_to_break;
#
# Return a list of continents owned by a single player which isn't the
# ai.
#
sub _continents_to_break {
    my ($self) = @_;
    my $me = $self->player;

    # owned continents, sorted by worth value
    my @to_break =
        grep { not $_->is_owned($me) }
        sort { $b->bonus <=> $a->bonus }
        $self->map->continents_owned;

    return @to_break;
}


#
# my $country = $self->_country_to_attack_from_small;
#
# Return a country that can be used to attack neighbours. The country
# should be next to an enemy, and have less than 11 armies.
#
sub _country_to_attack_from_small {
    my ($self) = @_;

    foreach my $country ( $self->player->countries ) {
        next if $self->_owns_neighbours($country);
        next if $country->armies > 11;
        return $country;
    }

    return;
}


#
# my $country = $self->_country_to_block_continent;
#
# Return a country on a continent almost owned by another player. This
# will be used to pile up armies on it, to block continent from falling
# in the hands of the other player.
#
sub _country_to_block_continent {
    my ($self) = @_;
    my $me   = $self->player;
    my $game = $self->game;
    my $map  = $game->map;

    PLAYER:
    foreach my $player ( $game->players_active ) {
        next PLAYER if $player eq $me;

        CONTINENT:
        foreach my $continent ( $map->continents ) {
            next CONTINENT unless $self->_almost_owned($player, $continent);
            next CONTINENT if     $continent->is_owned($player);

            # continent almost owned, let's try to block!
            COUNTRY:
            foreach my $country ( $continent->countries ) {
                next COUNTRY if $country->owner ne $me;
                next COUNTRY if $country->armies > 5;

                # ok, we've found a country to fortify.
                return $country;
            }
        }
    }

    return;
}


#
# my $country = $self->_country_to_crush_weak_enemy;
#
# Return a country that can be used to crush a weak enemy.
#
sub _country_to_crush_weak_enemy {
    my ($self) = @_;

    # find weak players
    my @weaks =
        grep { scalar($_->countries) < 4 }  # less than 4 countries
        $self->game->players_active;
    return unless @weaks;

    # potential targets
    my @targets = map { $_->countries } @weaks;

    COUNTRY:
    foreach my $country ( $self->player->countries ) {
        WEAK:
        foreach my $target ( @targets ) {
            next WEAK unless $country->is_neighbour($target);
            return $country;
        }
    }

    return;
}


#
# my $country = $self->_country_to_free_continent;
#
# Return a country that can be used to attack a continent owned by another player. This
# will prevent the user from getting the bonus.
#
sub _country_to_free_continent {
    my ($self) = @_;

    my @to_break = $self->_continents_to_break;

    RANGE:
    foreach my $range ( 1 .. 4 ) {
        foreach my $continent ( @to_break ) {
            foreach my $country ( @my_countries ) {
                NEIGHBOUR:
                foreach my $neighbour ( $coutry->neighbours ) {
                    my $freeable = _short_path_to_continent(
                        $continent, $country, $neighbour, $range);
                    next NEIGHBOUR if not $freeable;
                    # eheh, we found a path!
                    return $country;
                }
            }
        }
    }

    return;
}


#
# my $descr = $ai->_description;
#
# Return a brief description of the ai and the way it operates.
#
sub _description {
    return q{

        This artificial intelligence is optimized to conquer the world.
        It checks what countries are most valuable for it, optimizes
        attacks and moves for continent bonus and blocking other
        players.

    };
}


#
# my $bool = $ai->_own_neighbours($country);
#
# Return true if ai also owns all the neighbours of $country.
#
sub _own_neighbours {
    my ($self, $country) = @_;

    my $player = $self->player;
    return all { $_->owner eq $player } $country->neighbours;
}


#--
# SUBROUTINES

# -- private subs

#
# my $bool = _short_path_to_continent( $continent,
#                                      $from, $through, $range );
#
# Return true if $continent is within $range (integer) of $from, going
# through country $through.
#
sub _short_path_to_continent {
    my ($continent, $from, $through, $range) = @_;

    # can't attack if both $from and $through are owned by the same
    # player, or if they are not neighbour of each-other.
    return 0 unless $from->is_neighbour($through);
    return 0 if $from->owner eq $through->owner;

    # definitely not within range.
    return 0 if $range <= 0 && $from->continent ne $continent;

    # within range.
    return 1 if $from->continent eq $continent;
    return 1 if $range > 0 && $through->continent eq $continent;

    # not currently within range, let's try one hop further.
    foreach my $country ( $through->neigbours ) {
        return 1 if
            _short_path_to_continent($continent, $through, $country, $range-1);
    }

    # dead-end, abort this path.
    return 0;
}

1;

__END__



=head1 NAME

Games::Risk::AI::Hegemon - ai that tries to conquer the world



=head1 SYNOPSIS

    my $ai = Games::Risk::AI::Hegemon->new(\%params);



=head1 DESCRIPTION

This artificial intelligence is optimized to conquer the world.  It
checks what countries are most valuable for it, optimizes attacks and
moves for continent bonus and blocking other players.



=head1 METHODS

This class implements (or inherits) all of those methods (further described in
C<Games::Risk::AI>):


=over 4

=item * attack()

=item * attack_move()

=item * description()

=item * difficulty()

=item * move_armies()

=item * place_armies()

=back



=head1 SEE ALSO

L<Games::Risk::AI>, L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

