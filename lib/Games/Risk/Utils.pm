use 5.010;
use strict;
use warnings;

package Games::Risk::Utils;
# ABSTRACT: various utilities for prisk

use Exporter::Lite;
use File::ShareDir::PathClass;
use FindBin   qw{ $Bin };
use Path::Class;
 
our @EXPORT_OK = qw{ $SHAREDIR debug };

our $SHAREDIR = -e file("dist.ini") && -d dir("share")
    ? dir ("share")
    : File::ShareDir::PathClass->dist_dir("Games-Risk");


=method debug( @stuff );

Output C<@stuff> on stderr if we're in a local git checkout. Do nothing
in regular builds.

=cut

my $debug = -d dir($Bin)->parent->subdir('.git');
sub debug {
    return unless $debug;
    my ($package, $filename, $line) = caller;
    warn "$package($line) @_";
}


1;
__END__

=head1 DESCRIPTION

This module provides some helper variables and subs, to be used on
various occasions throughout the code.

