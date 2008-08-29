#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::AI::Dumb;

use strict;
use warnings;

sub description {
    my $descr = q{

        This artificial intelligence does nothing: it just piles up new armies
        randomly, and never ever attacks nor move armies.

    };

    $descr =~ s/[\n\s]+\z//;
    $descr =~ s/\A\n+//;
    return $descr;
}

sub difficulty { return 'very easy' }

1;

__END__



=head1 NAME

Games::Risk::AI::Dumb - dumb ai that does nothing



=head1 SYNOPSIS

    my $ai = Games::Risk::AI::Dumb->new(\%params);



=head1 DESCRIPTION

This module implements a dumb ai for risk, that does nothing. It just piles up
new armies randomly, and never ever attacks nor move armies.




=head1 SEE ALSO

L<Games::Risk::AI>, L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

