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
{
  $Games::Risk::Utils::VERSION = '3.112450';
}
# ABSTRACT: various utilities for prisk

use Exporter::Lite;
use File::ShareDir::PathClass;
use FindBin         qw{ $Bin };
use Path::Class;
use Term::ANSIColor qw{ :constants };
use Text::Padding;
 
our @EXPORT_OK = qw{ $SHAREDIR debug };

our $SHAREDIR = -e file("dist.ini") && -d dir("share")
    ? dir ("share")
    : File::ShareDir::PathClass->dist_dir("Games-Risk");



my $debug = -d dir($Bin)->parent->subdir('.git');
my $pad   = Text::Padding->new;
sub debug {
    return unless $debug;
    my ($pkg, $filename, $line) = caller;
    $pkg =~ s/^Games::Risk:://g;
    # BLUE and YELLOW have a length of 5. RESET has a length of 4
    my $prefix = $pad->right( BLUE . $pkg . YELLOW . ":$line" . RESET, 35);
    warn "$prefix @_";
}


1;


=pod

=head1 NAME

Games::Risk::Utils - various utilities for prisk

=head1 VERSION

version 3.112450

=head1 DESCRIPTION

This module provides some helper variables and subs, to be used on
various occasions throughout the code.

=head1 METHODS

=head2 debug( @stuff );

Output C<@stuff> on stderr if we're in a local git checkout. Do nothing
in regular builds.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__

