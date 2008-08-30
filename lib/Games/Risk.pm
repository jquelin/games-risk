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
use aliased 'POE::Kernel' => 'K';


# Public variables of the module.
our $VERSION = '0.1.3';


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
            _countries_assigned => \&_onpriv_place_initial_armies,
            _place_initial_armies   => \&_onpriv_place_initial_armies,
            # public events
            window_created      => \&_onpub_window_created,
            map_loaded          => \&_onpub_map_loaded,
        },
    );
    return $session->ID;
}


#--
# EVENTS HANDLERS

# -- public events

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
    foreach my $player ( @players ) {
        K->post('board', 'player_add', $player);
    }

    $h->_players(\@players); # FIXME: private

    # go on to the next phase
    K->yield( '_players_created' );
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
# require players to place initials armies.
#
sub _onpriv_place_initial_armies {
    my $h = $_[HEAP];

    my $left = $h->armies;
    given ($left) {
        when (undef) {
            $h->players_reset;
            $h->armies(7); # FIXME: hardcoded
            K->yield('_place_initial_armies');
        }
        when (0) {
            # go on to the next phase
            K->yield( '_initial_armies_placed' );
        }
        default {
            my $player = $h->players_next;
            $player  //= $h->players_next; # eot doesn't mean anything here
            K->post('board', 'player_active', $player); # FIXME: broadcast
        }
    }
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



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

