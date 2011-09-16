use 5.010;
use strict;
use warnings;

package Games::Risk::Player;
# ABSTRACT: risk player

use POE qw{ Loop::Tk };
use Carp;
use Games::Risk::AI;
use List::Util qw{ sum };
use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;
use Readonly;
use UNIVERSAL::require;
use constant K => $poe_kernel;

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

The class of the artificial intelligence, if player is an ai.

=cut

has ai_class  => ( ro, isa=>"Str" );
has ai        => ( rw, isa=>"Games::Risk::AI", lazy_build );

has cards => ( ro, isa=>"Games::Risk::Deck", default=>sub{ Games::Risk::Deck->new } );


#-- builder / finalizer

sub DEMOLISH { debug( "~player " . $_[0]->name ."\n" ); }

sub BUILD {
    my $self = shift;

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
            $self->set_ai($ai);
        }
    }
}



# -- public methods

#
# my @countries = $player->countries;
#
# Return the list of countries (Games::Risk::Country objects)
# currently owned by $player.
#
sub countries {
    my ($self) = @_;
    my $map = Games::Risk->instance->map;
    return grep { $_->owner eq $self } $map->countries;
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



__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    DEMOLISH


=head1 DESCRIPTION

This module implements a risk player, with all its characteristics.


=back



=head2 Object methods

The following methods are available for C<Games::Risk::Player> objects:


=over 4

=item my @cards = $player->cards()

Return the list of cards (C<Games::Risk::Card> objects) currently
owned by C<$player>.


=item * my @countries = $player->countries()

Return the list of countries (C<Games::Risk::Country> objects)
currently owned by C<$player>.


=item * my $greatness = $player->greatness()

Return an integer reflecting the greatness of C<$player>. It will raise
with the number of owned territories, as well as the number of armies.


=back



=head1 SEE ALSO

L<Games::Risk>.

