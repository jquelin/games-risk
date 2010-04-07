#!perl
#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

BEGIN { require 5.010; }
use strict;
use warnings;

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME          => 'Games::Risk',
    AUTHOR        => 'Jerome Quelin, <jquelin@cpan.org>',
    VERSION_FROM  => 'lib/Games/Risk.pm',
    ABSTRACT_FROM => 'lib/Games/Risk.pm',
    EXE_FILES     => [ 'bin/prisk' ],
    LICENSE       => 'gpl',
    PREREQ_PM     => {
        'aliased'                => 0,
        'Class::Accessor::Fast'  => 0,
        'File::Basename'         => 0,
        'File::Temp'             => 0,
        'Getopt::Euclid'         => 0,
        'Image::Imlib2'          => 0,
        'Image::Size'            => 0,
        'List::MoreUtils'        => 0,
        'List::Util'             => 0,
        'MIME::Base64'           => 0,
        'Module::Util'           => 0,
        'POE'                    => 0,
        'POE::Loop::Tk'          => 0,
        'Readonly'               => 0,
        'Tk'                     => 0,
        'Tk::Balloon'            => 0,
        'Tk::Font'               => 0,
        'Tk::JPEG'               => 0,
        'Tk::Pane'               => 0,
        'Tk::PNG'                => 0,
        'Test::More'             => 0,
        'UNIVERSAL::require'     => 0,
    },
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean         => { FILES => [
                    'Games-Risk-*',
					map { ( '*/' x $_ ) . '*~' } 0..5 ] },
    test          => { TESTS => 't/*.t t/*/*.t' },
);


