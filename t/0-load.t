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

use Test::More tests => 13;

BEGIN { use_ok( 'Games::Risk' ); }
diag( "Testing Games::Risk $Games::Risk::VERSION, Perl $], $^X" );
BEGIN { use_ok( 'Games::Risk::Controller' ); }
BEGIN { use_ok( 'Games::Risk::AI' ); }
BEGIN { use_ok( 'Games::Risk::AI::Blitzkrieg' ); }
BEGIN { use_ok( 'Games::Risk::AI::Dumb' ); }
BEGIN { use_ok( 'Games::Risk::AI::Hegemon' ); }
BEGIN { use_ok( 'Games::Risk::GUI' ); }
BEGIN { use_ok( 'Games::Risk::GUI::Board' ); }
BEGIN { use_ok( 'Games::Risk::GUI::MoveArmies' ); }
BEGIN { use_ok( 'Games::Risk::Map' ); }
BEGIN { use_ok( 'Games::Risk::Map::Continent' ); }
BEGIN { use_ok( 'Games::Risk::Map::Country' ); }
BEGIN { use_ok( 'Games::Risk::Player' ); }

exit;
