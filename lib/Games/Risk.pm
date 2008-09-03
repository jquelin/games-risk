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

use Games::Risk::GUI::Board;
use Games::Risk::Heap;
use Games::Risk::Map;
use Games::Risk::Player;
use List::Util   qw{ min shuffle };
use Module::Util qw{ find_installed };
use POE;
use Readonly;
use aliased 'POE::Kernel' => 'K';


# Public variables of the module.
our $VERSION = '0.3.2';

Readonly my $ATTACK_WAIT => 0.300; # FIXME: hardcoded
Readonly my $TURN_WAIT => 0.300; # FIXME: hardcoded
Readonly my $WAIT      => 0.100; # FIXME: hardcoded


#--
# CLASS METHODS

# -- public methods

#
# my $id = Games::Risk->spawn( \%params )
#
# This method will create a POE session responsible for a classical risk
# game. It will return the poe id of the session newly created.
#
# You can tune the session by passing some arguments as a hash reference.
# Currently, no params can be tuned.
#
sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        heap          => Games::Risk::Heap->new,
        inline_states => {
            # private events - session management
            _start         => \&_onpriv_start,
            _stop          => sub { warn "GR shutdown\n" },
            # private events - game states
            _started            => \&_onpriv_load_map,
            _gui_ready          => \&_onpriv_create_players,
            _players_created    => \&_onpriv_assign_countries,
            _countries_assigned => \&_onpriv_place_armies_initial,
            _place_armies_initial   => \&_onpriv_place_armies_initial,
            _initial_armies_placed  => \&_onpriv_turn_begin,
            _begin_turn             => \&_onpriv_turn_begin,
            _turn_begun             => \&_onpriv_player_next,
            _player_begun           => \&_onpriv_place_armies,
            _armies_placed          => \&_onpriv_attack,
            _attack_done            => \&_onpriv_attack_done,
            _attack_end             => \&_onpriv_player_next,
            # public events
            window_created      => \&_onpub_window_created,
            map_loaded          => \&_onpub_map_loaded,
            player_created      => \&_onpub_player_created,
            initial_armies_placed       => \&_onpub_initial_armies_placed,
            armies_placed       => \&_onpub_armies_placed,
            attack                  => \&_onpub_attack,
            attack_move             => \&_onpub_attack_move,
            attack_end              => \&_onpub_attack_end,
        },
    );
    return $session->ID;
}


#--
# EVENTS HANDLERS

# -- public events

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
    $losses[ $attack[1] <= $defence[1] ? 0 : 1 ]++ if $nbdice_dst == 2;

    # update countries
    $src->armies( $src->armies - $losses[0] );
    $dst->armies( $dst->armies - $losses[1] );

    # post damages
    # FIXME: only for human player?
    K->post('board', 'attack_info', $src, $dst, \@attack, \@defence); # FIXME: broadcast

    K->delay_set( '_attack_done' => $ATTACK_WAIT, $src, $dst );
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

    # update the countries
    $src->armies( $src->armies - $nb );
    $dst->armies( $nb );
    $dst->chown( $src->owner );

    # update the gui
    K->post('board', 'chnum', $src); # FIXME: broadcast
    K->post('board', 'chown', $dst); # FIXME: broadcast

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
        my $session;
        given ($player->type) {
            when ('ai')    { $session = $player->name; }
            when ('human') { $session = 'invasion'; } #FIXME: broadcast
        }
        K->post($session, 'attack_move', $src, $dst, $h->nbdice);

    } else {
        K->post($session, 'attack');
    }

}


#
# create the GR::Players that will fight.
#
sub _onpriv_create_players {
    my $h = $_[HEAP];

    # create players - FIXME: number of players
    my @players;
    push @players, Games::Risk::Player->new({type=>'human'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Dumb'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Dumb'});
    push @players, Games::Risk::Player->new({type=>'ai', ai_class => 'Games::Risk::AI::Dumb'});

    @players = shuffle @players;

    #FIXME: broadcast
    $h->wait_for( {} );
    foreach my $player ( @players ) {
        $h->wait_for->{ $player->name } = 1;
        K->post('board', 'player_add', $player);
    }

    $h->_players(\@players); # FIXME: private
}


#
# load map in memory.
#
sub _onpriv_load_map {
    my $h = $_[HEAP];

    # load model
    # FIXME: hardcoded
    my $path = find_installed(__PACKAGE__);
    $path =~ s/\.pm$//;
    $path .= '/maps/risk.map';
    my $map = Games::Risk::Map->new;
    $map->load_file($path);
    $h->map($map);
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
    $h->armies($nb);

    # FIXME: continent bonus

    my $session;
    given ($player->type) {
        when ('ai')    { $session = $player->name; }
        when ('human') { $session = 'board'; } #FIXME: broadcast
    }
    K->post($session, 'place_armies', $nb);
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

        $h->armies(2); # FIXME: hardcoded
        $left = $h->{armies};
        K->post('board', 'place_armies_initial_count', $left); # FIXME: broadcast & ai (?)
    }

    # get next player that should place an army
    my $player = $h->players_next;

    if ( not defined $player ) {
        # all players have placed an army once. so let's just decrease
        # count of armies to be placed, and start again.

        $player = $h->players_next;
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
    my $player = $h->players_next;
    $h->curplayer( $player );
    if ( not defined $player ) {
        K->yield('_begin_turn');
        return;
    }

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

    # prettyfying tk app.
    # see http://www.perltk.org/index.php?option=com_content&task=view&id=43&Itemid=37
    $poe_main_window->optionAdd('*BorderWidth' => 1);

    Games::Risk::GUI::Board->spawn({toplevel=>$poe_main_window});
    K->yield( '_started' );
}



1;
__END__


=head1 NAME

Games::Risk - classical 'risk' board game



=head1 SYNOPSIS

    use Games::Risk;
    Games::Risk->spawn;
    POE::Kernel->run;
    exit;



=head1 DESCRIPTION

Risk is a strategic turn-based board game. Players control armies, with
which they attempt to capture territories from other players. The goal
of the game is to control all the territories (C<conquer the world>)
through the elimination of the other players. Using area movement, Risk
ignores realistic limitations, such as the vast size of the world, and
the logistics of long campaigns.

This module implements a graphical interface for this game.



=head1 PUBLIC METHODS

=head2 my $id = Games::Risk->spawn( \%params )

This method will create a POE session responsible for a classical risk
game. It will return the poe id of the session newly created.

You can tune the session by passing some arguments as a hash reference.
Currently, no params can be tuned.


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

