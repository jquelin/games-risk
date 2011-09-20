use 5.010;
use strict;
use warnings;

package Games::Risk::Utils;
# ABSTRACT: various utilities for prisk

use Exporter::Lite;
use File::ShareDir::PathClass;
use Path::Class;
 
our @EXPORT_OK = qw{ $SHAREDIR debug };

our $SHAREDIR = -e file("dist.ini") && file("dist.ini")->slurp !~ /Maps/
    ? dir ("share")
    : File::ShareDir::PathClass->dist_dir("Games-Risk");

1;
__END__

=head1 DESCRIPTION

This module provides some helper variables and subs, to be used on
various occasions throughout the code.

