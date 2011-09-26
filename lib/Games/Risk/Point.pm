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

package Games::Risk::Point;
{
  $Games::Risk::Point::VERSION = '3.112690';
}
# ABSTRACT: placeholder for a 2D point

use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;


# -- public attributes


has coordx => ( rw, isa=>'Num', required );
has coordy => ( rw, isa=>'Num', required );

no Moose;
__PACKAGE__->meta->make_immutable;

1;


=pod

=head1 NAME

Games::Risk::Point - placeholder for a 2D point

=head1 VERSION

version 3.112690

=head1 DESCRIPTION

This module implements a basic point, which is a 2D vector.

=head1 ATTRIBUTES

=head2 coordx

=head2 coordy

The coordinates of the point.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__

