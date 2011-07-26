use 5.010;
use strict;
use warnings;

package Games::Risk::Point;
# ABSTRACT: placeholder for a 2D point

use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;


# -- public attributes

=attr coordx

=attr coordy

The coordinates of the point.

=cut

has coordx => ( rw, isa=>'Int', required );
has coordy => ( rw, isa=>'Int', required );

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DESCRIPTION

This module implements a basic point, which is a 2D vector.

