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

use Test::More tests => 4;

BEGIN { use_ok( 'Games::Risk' ); }
diag( "Testing Games::Risk $Games::Risk::VERSION, Perl $], $^X" );
BEGIN { use_ok( 'Games::Risk::Player' ); }
BEGIN { use_ok( 'Games::Risk::GUI' ); }
BEGIN { use_ok( 'Games::Risk::GUI::Board' ); }

exit;
