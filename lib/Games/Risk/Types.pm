use 5.010;
use strict;
use warnings;

package Games::Risk::Types;
# ABSTRACT: various types used in the distribution

use Moose::Util::TypeConstraints;

enum CardType => qw{ artillery cavalery infantery joker };

1;
__END__

=head1 DESCRIPTION

This module defines and exports the types used by other modules of the
distribution.

The exported types are:

=over 4

=item CardType - the type of the card.

=back
