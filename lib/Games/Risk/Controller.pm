#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Controller;

use 5.010;
use strict;
use warnings;

use File::Basename  qw{ fileparse };
use Games::Risk::Map;
use Games::Risk::Player;
use List::Util      qw{ min shuffle };
use Module::Util    qw{ find_installed };
use POE;
use Readonly;
use aliased 'POE::Kernel' => 'K';


Readonly my $ATTACK_WAIT_AI    => 1.250; # FIXME: hardcoded
Readonly my $ATTACK_WAIT_HUMAN => 0.300; # FIXME: hardcoded
Readonly my $TURN_WAIT         => 1.800; # FIXME: hardcoded
Readonly my $WAIT              => 0.100; # FIXME: hardcoded
Readonly my $START_ARMIES      => 5;



#--
# CLASS METHODS

# -- public methods

#
# my $id = Games::Risk::Controller->spawn( \%params )
#
# This method will create a POE session responsible for a classical risk
# game. It will return the poe id of the session newly created.
#
# You can tune the session by passing some arguments as a hash reference.
# Currently, no params can be tuned.
#
sub spawn {
    my ($type, $game) = @_;

    my $session = POE::Session->create(
        heap          => $game,
        inline_states => {
            # private events - session management
            _start                  => \&_onpriv_start,
            _stop                   => sub { warn "GR shutdown\n" },
            # private events - game states
            _started                => \&_onpriv_load_map,
            _gui_ready              => \&_onpriv_create_players,
            _players_created        => \&_onpriv_assign_countries,
            _countries_assigned     => \&_onpriv_place_armies_initial,
            _place_armies_initial   => \&_onpriv_place_armies_initial,
            _initial_armies_placed  => \&_onpriv_turn_begin,
            _begin_turn             => \&_onpriv_turn_begin,
            _turn_begun             => \&_onpriv_player_next,
            _player_begun           => \&_onpriv_cards_exchange,
            _cards_exchanged        => \&_onpriv_place_armies,
            _armies_placed          => \&_onpriv_attack,
            _attack_done            => \&_onpriv_attack_done,
            _attack_end             => \&_onpriv_move_armies,
            _armies_moved           => \&_onpriv_player_next,
            # public events
            window_created          => \&_onpub_window_created,
            map_loaded              => \&_onpub_map_loaded,
            player_created          => \&_onpub_player_created,
            initial_armies_placed   => \&_onpub_initial_armies_placed,
            armies_moved            => \&_onpub_armies_moved,
            cards_exchange          => \&_onpub_cards_exchange,
            armies_placed           => \&_onpub_armies_placed,
            attack                  => \&_onpub_attack,
            attack_move             => \&_onpub_attack_move,
            attack_end              => \&_onpub_attack_end,
            move_armies             => \&_onpub_move_armies,
        },
    );
    return $session->ID;
}


#--
# EVENTS HANDLERS

# -- public events

#
# event: armies_moved();
#
# fired when player has finished moved armies at the end of the turn.
#
sub _onpub_armies_moved {
    my $h = $_[HEAP];

    # FIXME: check player is curplayer
    K->delay_set( '_armies_moved' => $WAIT );
}


#
# event: armies_placed($country, $nb);
#
# fired to place $nb additional armies on $country.
#
sub _onpub_armies_placed {
    my ($h, $country, $nb) = @_[HEAP,ARG0, ARG1];

    # FIXME: check player is curplayer
    # FIXME: check country belongs to curplayer
    # FIXME: check validity regarding total number
    # FIXME: check validity regarding continent
    # FIXME: check negative values
    my $left = $h->armies - $nb;
    $h->armies($left);

    $country->armies( $country->armies + $nb );
    K->post('board', 'chnum', $country); # FIXME: broadcast

    if ( $left == 0 ) {
        K->delay_set( '_armies_placed' => $WAIT );
    }
}


#
# event: attack( $src, $dst );
#
# fired when a player wants to attack country $dst from $src.
#
sub _onpub_attack {
    my ($h, $src, $dst) = @_[HEAP, ARG0, ARG1];

    my $player = $h->curplayer;

    # FIXME: check player is curplayer
    # FIXME: check src belongs to curplayer
    # FIXME: check dst doesn't belong to curplayer
    # FIXME: check countries src & dst are neighbours
    # FIXME: check src has at least 1 army

    my $armies_src = $src->armies - 1; # 1 army to hold $src
    my $armies_dst = $dst->armies;
    $h->src($src);
    $h->dst($dst);


    # roll the dices for the attacker
    my $nbdice_src = min $armies_src, 3; # don't attack with more than 3 armies
    my @attack;
    push( @attack, int(rand(6)+1) ) for 1 .. $nbdice_src;
    @attack = reverse sort @attack;
    $h->nbdice($nbdice_src); # store number of attack dice, needed for invading

    # roll the dices for the defender. don't defend with 2nd dice if we
    # don't have at least 50% luck to win with it. FIXME: customizable?
    my $nbdice_dst = $nbdice_src > 1
        ? $attack[1] > 4 ? 1 : 2
        : 2; # defend with 2 dices if attacker has only one
    $nbdice_dst = min $armies_dst, $nbdice_dst;
    my @defence;
    push( @defence, int(rand(6)+1) ) for 1 .. $nbdice_dst;
    @defence = reverse sort @defence;

    # compute losses
    my @losses  = (0, 0);
    $losses[ $attack[0] <= $defence[0] ? 0 : 1 ]++;
    $losses[ $attack[1] <= $defence[1] ? 0 : 1 ]++
        if $nbdice_src >= 2 && $nbdice_dst == 2;

    # update countries
    $src->armies( $src->armies - $losses[0] );
    $dst->armies( $dst->armies - $losses[1] );

    # post damages
    # FIXME: only for human player?
    K->post('board', 'attack_info', $src, $dst, \@attack, \@defence); # FIXME: broadcast

    my $wait = $player->type eq 'ai' ? $ATTACK_WAIT_AI : $ATTACK_WAIT_HUMAN;
    K->delay_set( '_attack_done' => $wait, $src, $dst );
}


#
# event: attack_end();
#
# fired when a player does not want to attack anymore during her turn.
#
sub _onpub_attack_end {
    K->delay_set( '_attack_end' => $WAIT );
}


#
# event: attack_move($src, $dst, $nb)
#
# request to invade $dst from $src with $nb armies.
#
sub _onpub_attack_move {
    my ($h, $src, $dst, $nb) = @_[HEAP, ARG0..$#_];

    # FIXME: check player is curplayer
    # FIXME: check $src & $dst
    # FIXME: check $nb is more than min
    # FIXME: check $nb is less than max - 1

    my $looser = $dst->owner;

    # update the countries
    $src->armies( $src->armies - $nb );
    $dst->armies( $nb );
    $dst->chown( $src->owner );

    # update the gui
    K->post('board', 'chnum', $src); # FIXME: broadcast
    K->post('board', 'chown', $dst); # FIXME: broadcast

    # check if previous $dst owner has lost.
    if ( scalar($looser->countries) == 0 ) {
        # omg! one player left
        $h->player_lost($looser);
        K->post('board', 'player_lost', $looser); # FIXME: broadcast

        # distribute cards from lost player to the one who crushed her
        my @cards = $looser->cards;
        my $player = $h->curplayer;
        my $session;
        given ($player->type) {
            when ('ai')    { $session = $player->name; }
            when ('human') { $session = 'cards'; } #FIXME: broadcast
        }
        my $sessionloose;
        given ($looser->type) {
            when ('ai')    { $sessionloose = $player->name; }
            when ('human') { $sessionloose = 'cards'; } #FIXME: broadcast
        }
        foreach my $card ( @cards ) {
            $looser->card_del($card);
            $player->card_add($card);
            K->post($session, 'card_add', $card);
            K->post($sessionloose, 'card_del', $card);
        }

        # check if game is over
        my @active = $h->players_active;
        if ( scalar @active == 1 ) {
            K->post('board', 'game_over', $player); # FIXME: broadcast
            return;
        }
    }

    # continue attack
    my $session;
    my $player = $h->curplayer;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }
    K->post($session, 'attack');
}


#
# event: cards_exchange($card, $card, $card)
#
# exchange the cards against some armies.
#
sub _onpub_cards_exchange {
    my ($h, @cards) = @_[HEAP, ARG0..$#_];
    my $player = $h->curplayer;

    # FIXME: check player is curplayer
    # FIXME: check cards belong to player
    # FIXME: check we're in place_armies phase

    # compute player's bonus
    my $combo = join '', sort map { substr $_->type, 0, 1 } @cards;
    my $bonus;
    given ($combo) {
        when ( [ qw{ aci acj aij cij ajj cjj ijj jjj } ] ) { $bonus = 10; }
        when ( [ qw{ aaa aaj } ] ) { $bonus = 8; }
        when ( [ qw{ ccc ccj } ] ) { $bonus = 6; }
        when ( [ qw{ iii iij } ] ) { $bonus = 4; }
        default { $bonus = 0; }
    }

    # wrong combo
    return if $bonus == 0;

    # trade the armies
    my $armies = $h->armies + $bonus;
    $h->armies($armies);

    # signal that player has some more armies...
    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }
    K->post($session, 'place_armies', $bonus); # FIXME: broadcast

    # ... and maybe some country bonus...
    foreach my $card ( @cards ) {
        next if $card->type eq 'joker'; # joker do not bear a country
        my $country = $card->country;
        next unless $country->owner eq $player;
        $country->armies($country->armies + 2);
        K->post('board', 'chnum', $country); # FIXME: broadcast
    }

    # ... but some cards less.
    $player->card_del($_) foreach @cards;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'cards'; } #FIXME: broadcast
    }
    K->post($session, 'card_del', @cards);

    # finally, put back the cards on the deck
    $h->map->card_return($_) foreach @cards;
}


#
# event: initial_armies_placed($country, $nb);
#
# fired to place $nb additional armies on $country.
#
sub _onpub_initial_armies_placed {
    my ($h, $country, $nb) = @_[HEAP,ARG0, ARG1];

    # FIXME: check player is curplayer
    # FIXME: check country belongs to curplayer
    # FIXME: check validity regarding total number
    # FIXME: check validity regarding continent

    $country->armies( $country->armies + $nb );
    K->post('board', 'chnum', $country); # FIXME: broadcast
    K->delay_set( '_place_armies_initial' => $WAIT );
}


#
# event: map_loaded();
#
# fired when board has finished loading map.
#
sub _onpub_map_loaded {
    # FIXME: sync & wait when more than one window
    K->yield('_gui_ready');
}


#
# event: move_armies( $src, $dst, $nb )
#
# fired when player wants to move $nb armies from $src to $dst.
#
sub _onpub_move_armies {
    my ($h, $src, $dst, $nb) = @_[HEAP, ARG0..$#_];

    # FIXME: check player is curplayer
    # FIXME: check $src & $dst belong to curplayer
    # FIXME: check $src & $dst are adjacent
    # FIXME: check $src keeps one army
    # FIXME: check if army has not yet moved
    # FIXME: check negative values
    # FIXME: check max values

    $h->move_out->{ $src->id } += $nb;
    $h->move_in->{  $dst->id } += $nb;

    $src->armies( $src->armies - $nb );
    $dst->armies( $dst->armies + $nb );

    K->post('board', 'chnum', $src); # FIXME: broadcast
    K->post('board', 'chnum', $dst); # FIXME: broadcast
}


#
# event: player_created($player);
#
# fired when a player is ready. used as a checkpoint to be sure everyone
# is ready before moving on to next phase (assign countries).
#
sub _onpub_player_created {
    my ($h, $player) = @_[HEAP, ARG0];
    delete $h->wait_for->{ $player->name };

    # go on to the next phase
    K->yield( '_players_created' ) if scalar keys %{ $h->wait_for } == 0;
}


#
# event: window_created( $window );
#
# fired when a gui window has finished initialized.
#
sub _onpub_window_created {
    my ($h, $state, $win) = @_[HEAP, STATE, ARG0];

    # board needs to load the map
    if ( $win eq 'board' ) {
        if ( not defined $h->map ) {
            # map is not yet loaded, let's give it some more time
            # by just re-firing current event
            K->yield($state, $win);
            return;
        }
        K->post('board', 'load_map', $h->map);
    }
}


# -- private events - game states

#
# distribute randomly countries to players.
# FIXME: what in the case of a loaded game?
# FIXME: this can be configured so that players pick the countries
# of their choice, turn by turn
#
sub _onpriv_assign_countries {
    my $h = $_[HEAP];

    # initial random assignment of countries
    my @players   = $h->players;
    my @countries = shuffle $h->map->countries;
    while ( my $country = shift @countries ) {
        # rotate players
        my $player = shift @players;
        push @players, $player;

        # store new owner & place one army to start with
        $country->chown($player);
        $country->armies(1);
        K->post('board', 'chown', $country); # FIXME: broadcast
    }

    # go on to the next phase
    K->yield( '_countries_assigned' );
}


#
# start the attack phase for curplayer
#
sub _onpriv_attack {
    my $h = $_[HEAP];

    my $player = $h->curplayer;
    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }
    K->post($session, 'attack');
    K->post('cards', 'attack'); # FIXME: should not be alone like this, need a multiplexed in GR::GUI
    # FIXME: even more since the gui always get this event, even if it's not its turn to play
}


#
# event: _attack_done($src, $dst)
#
# check the outcome of attack of $dst from $src only used as a
# temporization, so this handler will always serve the same event.
#
sub _onpriv_attack_done {
    my ($h, $src, $dst) = @_[HEAP, ARG0..$#_];

    # update gui
    K->post('board', 'chnum', $src); # FIXME: broadcast
    K->post('board', 'chnum', $dst); # FIXME: broadcast

    # get who to send msg to
    my $player = $h->curplayer;
    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }

    # check outcome
    if ( $dst->armies <= 0 ) {
        # all your base are belong to us! :-)

        # distribute a card if that's the first successful attack in the
        # player's turn.
        if ( not $h->got_card ) {
            $h->got_card(1);
            my $card = $h->map->card_get;
            my $player = $h->curplayer;
            my $session;
            given ($player->type) {
                when ('ai')    { $session = $player->name; }
                when ('human') { $session = 'cards'; } #FIXME: broadcast
            }
            $player->card_add($card);
            K->post($session, 'card_add', $card);# FIXME: broadcast
        }

        # move armies to invade country
        if ( $src->armies - 1 == $h->nbdice ) {
            # erm, no choice but move all remaining armies
            K->yield( 'attack_move', $src, $dst, $h->nbdice );

        } else {
            # ask how many armies to move
            my $session;
            given ($player->type) {
                when ('ai')    { $session = $player->name; }
                when ('human') { $session = 'move-armies'; } #FIXME: broadcast
            }
            K->post($session, 'attack_move', $src, $dst, $h->nbdice);
        }

    } else {
        K->post($session, 'attack');
    }
}


#
# ask player to exchange cards if they want
#
sub _onpriv_cards_exchange {
    my $h = $_[HEAP];

    my $player = $h->curplayer;
    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'move-armies'; } #FIXME: broadcast
    }
    K->post($session, 'exchange_cards');
    K->yield('_cards_exchanged');
}


#
# create the GR::Players that will fight.
#
sub _onpriv_create_players {
    my $h = $_[HEAP];

    # create players - FIXME: number of players
    my @players;
    push @players, Games::Risk::Player->new({type=>'human'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Blitzkrieg'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Blitzkrieg'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Hegemon'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Hegemon'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Hegemon'});

    @players = shuffle @players;

    #FIXME: broadcast
    $h->wait_for( {} );
    foreach my $player ( @players ) {
        $h->wait_for->{ $player->name } = 1;
        K->post('board', 'player_add', $player);
    }

    $h->_players(\@players); # FIXME: private
    $h->_players_active(\@players); # FIXME: private
}


#
# load map in memory.
#
sub _onpriv_load_map {
    my $h = $_[HEAP];

    # load model
    # FIXME: hardcoded
    my $path = find_installed(__PACKAGE__);
    my (undef, $dirname, undef) = fileparse($path);
    $path = "$dirname/maps/risk.map";
    my $map = Games::Risk::Map->new;
    $map->load_file($path);
    $h->map($map);
}


#
# request current player to move armies
#
sub _onpriv_move_armies {
    my $h = $_[HEAP];

    # reset counters
    $h->move_in( {} );
    $h->move_out( {} );

    # add current player to move
    my $player = $h->curplayer;
    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }
    K->post($session, 'move_armies');
}


#
# require curplayer to place its reinforcements.
#
sub _onpriv_place_armies {
    my $h = $_[HEAP];
    my $player = $h->curplayer;

    # compute number of armies to be placed.
    my @countries = $player->countries;
    my $nb = int( scalar(@countries) / 3 );
    $nb = 3 if $nb < 3;

    # signal player
    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }
    K->post($session, 'place_armies', $nb);

    # continent bonus
    my $bonus = 0;
    foreach my $c( $h->map->continents ) {
        next unless $c->is_owned($player);

        my $bonus = $c->bonus;
        $nb += $bonus;
        K->post($session, 'place_armies', $bonus, $c); # FIXME: broadcast
    }
    K->post('cards', 'place_armies'); # FIXME: should not be alone like this, need a multiplexed in GR::GUI
    # FIXME: even more since the gui always get this event, even if it's not its turn to play

    $h->armies($nb);
}


#
# require players to place initials armies.
#
sub _onpriv_place_armies_initial {
    my $h = $_[HEAP];

    # FIXME: possibility to place armies randomly by server
    # FIXME: possibility to place armies according to map scenario

    # get number of armies to place left
    my $left = $h->armies;

    if ( not defined $left ) {
        # undef means that we are just beginning initial armies
        # placement. let's initialize list of players.
        $h->players_reset;

        $h->armies($START_ARMIES); # FIXME: hardcoded
        $left = $h->{armies};
        K->post('board', 'place_armies_initial_count', $left); # FIXME: broadcast & ai (?)
    }

    # get next player that should place an army
    my $player = $h->player_next;

    if ( not defined $player ) {
        # all players have placed an army once. so let's just decrease
        # count of armies to be placed, and start again.

        $player = $h->player_next;
        $left--;
        $h->armies( $left );

        if ( $left == 0 ) {
            # hey, we've finished! move on to the next phase.
            K->yield( '_initial_armies_placed' );
            return;
        }
    }

    # update various guis with current player
    $h->curplayer( $player );
    K->post('board', 'player_active', $player); # FIXME: broadcast

    # request army to be placed.
    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }
    K->post($session, 'place_armies_initial');
}


#
# get next player & update people.
#
sub _onpriv_player_next {
    my $h = $_[HEAP];

    # get next player
    my $player = $h->player_next;
    $h->curplayer( $player );
    if ( not defined $player ) {
        K->yield('_begin_turn');
        return;
    }

    # reset card status
    $h->got_card(0);

    # update various guis with current player
    K->post('board', 'player_active', $player); # FIXME: broadcast

    K->delay_set('_player_begun'=>$TURN_WAIT);
}


#
# initialize list of players for next turn.
#
sub _onpriv_turn_begin {
    my $h = $_[HEAP];

    # get next player
    $h->players_reset;

    # placing armies
    K->yield('_turn_begun');
}


# -- private events - session management

#
# event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my $h = $_[HEAP];

    K->alias_set('risk');
    K->yield( '_started' );
}



1;
__END__


=head1 NAME

Games::Risk::Controller - controller poe session for risk



=head1 SYNOPSIS

    use Games::Risk::Controller;
    Games::Risk::Controller->spawn;



=head1 DESCRIPTION

This module implements a poe session, responsible for the state tracking
as well as rule enforcement of the game.



=head1 PUBLIC METHODS

=head2 my $id = Games::Risk::Controller->spawn( \%params )

This method will create a POE session responsible for a classical risk
game. It will return the poe id of the session newly created.

You can tune the session by passing some arguments as a hash reference.
Currently, no params can be tuned.


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
it under the terms of the GNU GPLv3+.


=cut

