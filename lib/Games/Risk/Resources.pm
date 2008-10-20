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
use Tk;
use POE;

use base qw{ Exporter };
our @EXPORT_OK = qw{ image };
my %images;

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
    return catfile($dirname, 'resources');
}


#
# _load_tk_icons( $dirname );
#
# load tk icons from $dirname/images/tk_icons.
# code & artwork taken from Tk::ToolBar
#
sub _load_tk_icons {
    my ($dirname) = @_;

    my $path = catfile($dirname, 'images', 'tk_icons');
    open my $fh, '<', $path or die "can't open '$path': $!";
    while (<$fh>) {
        chomp;
        last if /^#/; # skip rest of file
        my ($name, $data) = (split /:/)[0, 4];
        $images{$name} = $poe_main_window->Photo(-data => $data);
    }
    close $fh;
}


#--
# INITIALIZATION

BEGIN {
    my $dirname = _find_resources_path();
    _load_tk_icons($dirname);
}


1;

__END__



=head1 NAME

Games::Risk::Resources - utility module to load bundled resources



=head1 SYNOPSIS

    use Games::Risk::Resources;
    my $image = image('actexit16');



=head1 DESCRIPTION

This module is a focal point to access all resources bundled with
C<Games::Risk>. Indeed, instead of each package to reinvent its loading
mechanism, this package provides handy functions to do that.

Moreover, by loading all the images at the same location, it will ensure
that they are not loaded twice, cutting memory eating.



=head1 SUBROUTINES



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

