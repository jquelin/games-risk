#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::AI::Dumb;

use 5.010;
use strict;
use warnings;

use base qw{ Games::Risk::AI };

#--
# METHODS

# -- public methods

#
# my $difficulty = $ai->difficulty;
#
# Return a difficulty level for the ai.
#
sub difficulty { return 'very easy' }


# -- private methods

#
# my $descr = $ai->_description;
#
# Return a brief description of the ai and the way it operates.
#
sub _description {
    return q{

        This artificial intelligence does nothing: it just piles up new armies
        randomly, and never ever attacks nor move armies.

    };
}

1;

__END__



=head1 NAME

Games::Risk::AI::Dumb - dumb ai that does nothing



=head1 SYNOPSIS

    my $ai = Games::Risk::AI::Dumb->new(\%params);



=head1 DESCRIPTION

This module implements a dumb ai for risk, that does nothing. It just piles up
new armies randomly, and never ever attacks nor move armies.



=head1 METHODS

This class implements (or inherits) all of those methods (further described in
C<Games::Risk::AI>):


=over 4

=item * description()

=item * difficulty()

=back



=head1 SEE ALSO

L<Games::Risk::AI>, L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

