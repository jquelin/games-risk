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

package Games::Risk::Utils;
BEGIN {
  $Games::Risk::Utils::VERSION = '3.112010';
}
# ABSTRACT: various utilities for prisk

use Exporter::Lite;
use File::ShareDir::PathClass;
 
our @EXPORT = qw{ $SHAREDIR };

our $SHAREDIR = File::ShareDir::PathClass->dist_dir("Games-Risk");


1;


=pod

=head1 NAME

Games::Risk::Utils - various utilities for prisk

=head1 VERSION

version 3.112010

=head1 DESCRIPTION

This module provides some helper variables and subs, to be used on
various occasions throughout the code.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__

