#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Player;

use 5.010;
use strict;
use warnings;

use Carp;
use Games::Risk::AI;
use List::Util qw{ sum };
use POE;
use Readonly;
use UNIVERSAL::require;
use aliased 'POE::Kernel' => 'K';

Readonly my @COLORS => (
    '#333333',  # grey20
    '#FF2052',  # awesome
    '#1560BD',  # denim
    '#33CC99',  # shamrock
    '#FF9966',  # atomic tangerine
    '#00755E',  # tropical rain forest
    '#9E5B40',  # sepia
    '#A50B5E',  # jazzberry jam
    '#A3E3ED',  # blizzard blue
);
my $Color_id = 0;


use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ ai ai_class color name type _cards _countries } );


#--
# CLASS METHODS

# -- constructors

#
# my $player = Games::Risk::Player->new( \%params );
#
# Constructor. New object can be tuned with %params.
# Currently, no params can be tuned.
#
sub new {
    my ($pkg, $args) = @_;

    # assign a new color
    my $nbcols = scalar(@COLORS);
    croak "can't assign more than $nbcols colors" if $Color_id >= $nbcols;
    my $color = $COLORS[ $Color_id++ ];

    # create the object
    my $self = bless $args, $pkg;

    # update other object attributes
    $self->color( $color );
    given ( $self->type ) {
        when ('human') {
            $self->name( $ENV{USER} ); # FIXME: portable enough?
            K->post('risk', 'player_created', $self);
        }
        when ('ai') {
            my $ai_class = $self->ai_class;
            $ai_class->require;
            my $ai = $ai_class->new({ player=>$self });
            Games::Risk::AI->spawn($ai);
            $self->ai($ai);
        }
    }

    return $self;
}


#--
# METHODS

# -- public methods

#
# my @cards = $player->cards;
#
# Return the list of cards (Games::Risk::Map::Card objects) currently
# owned by $player.
#
sub cards {
    my ($self) = @_;
    return @{ $self->_cards // [] };
}


#
# $player->card_add( $card );
#
# Add $card to the set of cards owned by $player.
#
sub card_add {
    my ($self, $card) = @_;
    my @cards = $self->cards;
    push @cards, $card;
    $self->_cards(\@cards);
}


#
# $player->card_del( $card );
#
# Remove $card from the set of cards owned by $player.
#
sub card_del {
    my ($self, $card) = @_;

    my @cards = grep { $_ ne $card } $self->cards;
    $self->_cards(\@cards);
}


#
# my @countries = $player->countries;
#
# Return the list of countries (Games::Risk::Map::Country objects)
# currently owned by $player.
#
sub countries {
    my ($self) = @_;
    return @{ $self->_countries // [] };
}


#
# $player->country_add( $country );
#
# Add $country to the set of countries owned by $player.
#
sub country_add {
    my ($self, $country) = @_;
    my @countries = $self->countries;
    push @countries, $country;
    $self->_countries(\@countries);
}


#
# $player->country_del( $country );
#
# Delete $country from the set of countries owned by $player.
#
sub country_del {
    my ($self, $country) = @_;
    my @countries = grep { $_->id != $country->id } $self->countries;
    $self->_countries(\@countries);
}


#
# my $greatness = $player->greatness;
#
# Return an integer reflecting the greatness of $player. It will raise
# with the number of owned territories, as well as the number of armies.
#
sub greatness {
    my ($self) = @_;
    my @countries = $self->countries;
    my $greatness = sum map { $_->armies } @countries;
    $greatness += scalar(@countries);
    return $greatness;
}



1;

__END__



=head1 NAME

Games::Risk::Player - risk player



=head1 SYNOPSIS

    my $id = Games::Risk::Player->new(\%params);



=head1 DESCRIPTION

This module implements a risk player, with all its characteristics.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $player = Games::Risk::Player->new( \%params )


=back



=head2 Accessors


The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Player> objects:


=over 4

=item * ai_class

the class of the artificial intelligence, if player is an ai.


=item * color

player color to be used in the gui.


=item * name

player name.


=item * type

player type (human, ai, etc.)


=back



=head2 Object methods

The following methods are available for C<Games::Risk::Player> objects:


=over 4

=item my @cards = $player->cards()

Return the list of cards (C<Games::Risk::Map::Card> objects) currently
owned by C<$player>.


=item * $player->card_add( $card )

Add C<$card> to the set of cards owned by C<$player>.


=item * $player->card_del( $card )

Remove C<$card> from the set of cards owned by C<player>.


=item * my @countries = $player->countries()

Return the list of countries (C<Games::Risk::Map::Country> objects)
currently owned by C<$player>.


=item * $player->country_add( $country )

Add C<$country> to the set of countries owned by C<$player>.


=item * $player->country_del( $country )

Delete C<$country> from the set of countries owned by C<$player>.


=item * my $greatness = $player->greatness()

Return an integer reflecting the greatness of C<$player>. It will raise
with the number of owned territories, as well as the number of armies.


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
it under the terms of the GNU GPLv3+.

=cut

