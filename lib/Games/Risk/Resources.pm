#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Resources;

use 5.010;
use strict;
use warnings;

use File::Basename qw{ fileparse };
use File::Spec::Functions;
use Module::Util   qw{ find_installed };

use base qw{ Exporter };

# -- module vars
our @EXPORT_OK = qw{ image };
my $resources;


#--
# SUBROUTINES


# -- private subs

#
# my $path = _find_resources_path();
#
# return the absolute path where all resources will be placed.
#
sub _find_resources_path {
    my $path = find_installed(__PACKAGE__);
    my (undef, $dirname, undef) = fileparse($path);
    return catfile($path, 'resources');
}

# -- init
BEGIN {
    $resources = _find_resources_path();
}


1;

__END__



=head1 NAME

Games::Risk::Resources - utility module to load bundled resources



=head1 SYNOPSIS

    use Games::Risk::Resources;
    


=head1 DESCRIPTION

This module implements a map, pointing to the continents, the
countries, etc. of the game currently in play.



=head1 METHODS

=head2 Constructor

=over 4

=item * my $player = Games::Risk::Map->new( \%params )


=back


=head2 Accessors


The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Map> objects:


=over 4

=item * background()

the path to the background image for the board.


=item * greyscale()

the path to the greyscale bitmap for the board.


=back


=head2 Object methods

=over 4

=item * $map->destroy()

Break all circular references in C<$map>, to prevent memory leaks.


=item * my $card = $map->card_get()

Return the next card from the cards stack.


=item * $map->card_return( $card )

Push back a $card in the card stack.


=item * my @continents = $map->continents()

Return the list of all continents in the C<$map>.


=item * my @owned = $map->continents_owned;

Return a list with all continents that are owned by a single player.


=item * my @countries = $map->countries()

Return the list of all countries in the C<$map>.


=item * my $country = $map->country_get($id)

Return the country which id matches C<$id>.


=item * $map->load_file( \%params )

=back



=begin quiet_pod_coverage

=item Card (inserted by aliased)

=item Continent (inserted by aliased)

=item Country (inserted by aliased)

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

