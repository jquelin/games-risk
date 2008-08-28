#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Player;

use strict;
use warnings;

use Readonly;

Readonly my @COLORS => (
    '#333333',  # grey20
    '#FE6F5E',  # bittersweet
    '#FFFF99',  # canary 
    '#1560BD',  # denim 
    '#5FA777',  # forest green 
    '#FBAED2',  # lavender 
    '#FFCBA4',  # peach 
    '#00CCCC',  # robin's egg blue 
    '#9E5B40',  # sepia 
);
my $Color => 0;


use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ color _countries } );


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

    my $self = bless {}, $pkg;
    $self->color( $COLORS[ $Color++ ] );
    # FIXME: what if beyond sepia
    return $self;
}


#--
# METHODS

# -- public methods

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


=head2 Object methods

The following methods are available for C<Games::Risk::Player> objects:


=over 4

=item * my @countries = $player->countries()

Return the list of countries (c>Games::Risk::Map::Country> objects)
currently owned by C<$player>.


=item * $player->country_add( $country )

Add C<$country> to the set of countries owned by C<$player>.


=item * $player->country_del( $country )

Delete C<$country> from the set of countries owned by C<$player>.


=back



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

