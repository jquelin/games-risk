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
use List::Util   qw{ shuffle };
use Module::Util qw{ find_installed };
use POE;
use Readonly;
use aliased 'POE::Kernel' => 'K';


# Public variables of the module.
our $VERSION = '0.2.4';

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
            _turn_began             => \&_onpriv_player_next,
            _place_armies           => \&_onpriv_place_armies,
            _armies_placed          => \&_onpriv_player_next,
            # public events
            window_created      => \&_onpub_window_created,
            map_loaded          => \&_onpub_map_loaded,
            player_created      => \&_onpub_player_created,
            initial_armies_placed       => \&_onpub_initial_armies_placed,
            armies_placed       => \&_onpub_armies_placed,
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
    my $left = $h->armies - $nb;
    $h->armies($left);

    $country->armies( $country->armies + $nb );
    K->post('board', 'chnum', $country); # FIXME: broadcast

    if ( $left == 0 ) {
        K->delay_set( '_armies_placed' => $WAIT );
    }
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
    K->delay_set( '_place_armies_initial' => $TURN_WAIT );
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

    K->delay_set('_place_armies'=>$TURN_WAIT);
}


#
# initialize list of players for next turn.
#
sub _onpriv_turn_begin {
    my $h = $_[HEAP];

    # get next player
    $h->players_reset;

    # placing armies
    K->yield('_turn_began');
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

Some ideas taken from project C<jrisk>, available at
L<http://risk.sourceforge.net/>. Others taken from teg, available at
L<http://teg.sourceforge.net/>



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

