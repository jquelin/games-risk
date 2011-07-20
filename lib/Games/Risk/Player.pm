#
# This file is part of Games-Risk
#
# This software is Copyright (c) 2008 by Jerome Quelin.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#
use 5.010;
use strict;
use warnings;

package Games::Risk::Player;
BEGIN {
  $Games::Risk::Player::VERSION = '3.112010';
}
# ABSTRACT: risk player

use POE qw{ Loop::Tk };
use Carp;
use Games::Risk::AI;
use List::Util qw{ sum };
use Readonly;
use UNIVERSAL::require;
use constant K => $poe_kernel;


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

    # create the object
    my $self = bless $args, $pkg;

    # update other object attributes
    given ( $self->type ) {
        when ('human') {
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
# Return the list of cards (Games::Risk::Card objects) currently
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
# Return the list of countries (Games::Risk::Country objects)
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
# $player->destroy;
#
# Break all circular references in $player, to prevent memory leaks.
#
#sub DESTROY { say "destroy: $_[0]"; }
sub destroy {
    my ($self) = @_;
    $self->ai(undef);
    $self->_cards([]);
    $self->_countries([]);
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



=pod

=head1 NAME

Games::Risk::Player - risk player

=head1 VERSION

version 3.112010

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

Return the list of cards (C<Games::Risk::Card> objects) currently
owned by C<$player>.

=item * $player->card_add( $card )

Add C<$card> to the set of cards owned by C<$player>.

=item * $player->card_del( $card )

Remove C<$card> from the set of cards owned by C<player>.

=item * my @countries = $player->countries()

Return the list of countries (C<Games::Risk::Country> objects)
currently owned by C<$player>.

=item * $player->country_add( $country )

Add C<$country> to the set of countries owned by C<$player>.

=item * $player->country_del( $country )

Delete C<$country> from the set of countries owned by C<$player>.

=item * $player->destroy()

Break all circular references in C<$player>, to prevent memory leaks.

=item * my $greatness = $player->greatness()

Return an integer reflecting the greatness of C<$player>. It will raise
with the number of owned territories, as well as the number of armies.

=back

=head1 SEE ALSO

L<Games::Risk>.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__




