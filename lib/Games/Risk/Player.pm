use 5.010;
use strict;
use warnings;

package Games::Risk::Player;
# ABSTRACT: risk player

use POE qw{ Loop::Tk };
use List::Util qw{ sum };
use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;
use Readonly;
use UNIVERSAL::require;

Readonly my $K => $poe_kernel;

use Games::Risk::AI;
use Games::Risk::Deck;
use Games::Risk::Logger qw{ debug };
use Games::Risk::Types;


# -- attributes

=attr type

Player type (human, ai, etc.)

=attr name

Player name.

=attr color

Player color to be used in the gui.

=cut

has type  => ( ro, isa=>"PlayerType", required );
has name  => ( ro, isa=>"Str", required );
has color => ( ro, isa=>"Str", required );


=attr ai_class

The class of the artificial intelligence, if player is an AI.

=attr ai

The reference to the actual AI object, if player is an AI.

=cut

has ai_class  => ( ro, isa=>"Str" );
has ai        => ( rw, isa=>"Games::Risk::AI", lazy_build );


=attr cards

The cards (a C<Games::Risk::Deck> object) currently owned by C<$player>.

=cut

has cards => ( ro, isa=>"Games::Risk::Deck", default=>sub{ Games::Risk::Deck->new } );


#-- builder / finalizer

sub DEMOLISH { debug( "~player " . $_[0]->name ."\n" ); }

sub BUILD {
    my $self = shift;

    # update other object attributes
    my $type = $self->type;
    if ( $type eq 'human' ) {
        $K->post('risk', 'player_created', $self);
    }
    elsif ( $type eq 'ai' ) {
        my $ai_class = $self->ai_class;
        $ai_class->require;
        my $ai = $ai_class->new({ player=>$self });
        Games::Risk::AI->spawn($ai);
        $self->set_ai($ai);
    }
}



# -- public methods


=method countries

    my @countries = $player->countries;

Return the list of countries (C<Games::Risk::Country> objects)
currently owned by C<$player>.

=cut

sub countries {
    my ($self) = @_;
    my $map = Games::Risk->instance->map;
    return grep { $_->owner eq $self } $map->countries;
}


=method greatness

    my $greatness = $player->greatness;

Return an integer reflecting the greatness of C<$player>. It will raise
with the number of owned territories, as well as the number of armies.

=cut

sub greatness {
    my ($self) = @_;
    my @countries = $self->countries;
    my $greatness = sum map { $_->armies } @countries;
    $greatness += scalar(@countries);
    return $greatness;
}


__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    BUILD
    DEMOLISH


=head1 DESCRIPTION

This module implements a risk player, with all its characteristics.

