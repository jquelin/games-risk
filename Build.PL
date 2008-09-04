#!perl
#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

use strict;
use warnings;

use Module::Build;

my %requires = (
    'perl'                   => '5.010',
    'aliased'                => 0,
    'Class::Accessor::Fast'  => 0,
    'File::Basename'         => 0,
    'Image::Size'            => 0,
    'List::MoreUtils'        => 0,
    'List::Util'             => 0,
    'Module::Util'           => 0,
    'POE'                    => 0,
    'Readonly'               => 0,
    'Tk'                     => 0,
    'Tk::Balloon'            => 0,
    'Tk::JPEG'               => 0,
    'Tk::PNG'                => 0,
    'UNIVERSAL::require'     => 0,
);
my %build_requires = (
    %requires,
    'Test::More'             => 0,
);
my %recommends = (
    'Test::Pod'              => 0,
    'Test::Pod::Coverage'    => 0,
);


my $builder = Module::Build->new
  ( module_name          => 'Games::Risk',
    license              => 'gpl',
    dist_author          => 'Jerome Quelin <jquelin@cpan.org>',
    dist_version_from    => 'lib/Games/Risk.pm',
    build_requires       => \%build_requires,
    requires             => \%requires,
    recommends           => \%recommends,
    script_files         => [ 'bin/prisk' ],
    add_to_cleanup       =>
      [ 'Games-Risk-*', map { ( '*/' x $_ ) . '*~' } 0..5 ],
    recursive_test_files => 1,
  );
$builder->create_build_script;

