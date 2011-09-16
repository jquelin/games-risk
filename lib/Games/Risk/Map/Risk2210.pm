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

package Games::Risk::Map::Risk2210;
{
  $Games::Risk::Map::Risk2210::VERSION = '3.112590';
}
# ABSTRACT: Risk 2210AD map

use utf8;

use Moose;
use Games::Risk::I18n qw{ T };
extends 'Games::Risk::Map';


# -- map  builders

sub name   { "risk2210" }
sub title  { T("Risk 2210 A.D.") }
sub author { "Matthias Kuehl" }


# -- raw map information

sub _raw_continents {
return (
# id, name, bonus, color
#   0, T('Europe'), 5, blue
[1, T("North America"), 5, "yellow"],
[2, T("South America"), 2, "red"],
[3, T("Europe"), 5, "blue"],
[4, T("Africa"), 3, "orange"],
[5, T("Asia"), 7, "green"],
[6, T("Australia"), 2, "magenta"],
[7, T("US Pacific"), 2, "blue"],
[8, T("Asia Pacific"), 1, "yellow"],
[9, T("North Atlantic"), 2, "red"],
[10, T("South Atlantic"), 1, "green"],
[11, T("Indian"), 2, "orange"],
);
}

sub _raw_countries {
return (
# greyscale, name, continent id, x, y, [connections]
#   1, T('Alaska'), 1, 43, 67, [ 1,2,3,38 ]
[1, T("Northwestern Oil Emirate"), 1, 47, 19, [2, 4, 38]],
[2, T("Nunavut"), 1, 105, 23, [1, 4, 5, 3]],
[3, T("Exiled States of America"), 1, 222, 23, [2, 6, 14]],
[4, T("Alberta"), 1, 85, 57, [1, 2, 5, 7]],
[5, T("Canada"), 1, 125, 67, [2, 4, 6, 7, 8]],
[6, T("République du Québec"), 1, 175, 75, [3, 5, 8]],
[7, T("Continental Biospheres"), 1, 80, 100, [4, 5, 8, 9, 45]],
[8, T("American Republic"), 1, 117, 121, [5, 6, 7, 9, 49]],
[9, T("Mexico"), 1, 81, 161, [7, 8, 10]],
[10, T("Nuevo Timoto"), 2, 115, 216, [9, 11, 12, 47]],
[11, T("Andean Nations"), 2, 94, 257, [10, 12, 13]],
[12, T("Amazon Desert"), 2, 145, 265, [10, 11, 13, 21, 50, 51]],
[13, T("Argentina"), 2, 90, 325, [11, 12]],
[14, T("Iceland GRC"), 3, 268, 47, [3, 17, 15]],
[15, T("Jotenheim"), 3, 328, 28, [16, 18, 14, 17]],
[16, T("Ukrayina"), 3, 412, 70, [15, 28, 30, 31, 18, 20]],
[17, T("New Avalon"), 3, 272, 84, [14, 18, 19, 15, 48]],
[18, T("Warsaw Republic"), 3, 333, 89, [15, 16, 17, 19, 20]],
[19, T("Andorra"), 3, 270, 132, [17, 18, 20, 21]],
[20, T("Imperial Balkania"), 3, 340, 116, [16, 18, 19, 21, 22, 31]],
[  21,  T("Saharan Empire"),  4,  280,  211,  [12, 19, 20, 22, 23, 24, 52],],
[22, T("Egypt"), 4, 350, 180, [20, 21, 24, 31]],
[23, T("Zaire Military Zone"), 4, 349, 274, [21, 24, 25]],
[24, T("Ministry of Djibouti"), 4, 395, 245, [21, 22, 23, 25, 26]],
[25, T("Lesotho"), 4, 357, 347, [23, 24, 26]],
[26, T("Madagascar"), 4, 417, 332, [24, 25, 54]],
[27, T("Siberia"), 5, 520, 32, [28, 29, 34, 35, 36]],
[28, T("Enclave of the Bear"), 5, 475, 65, [16, 27, 29, 30]],
[29, T("Hong Kong"), 5, 555, 145, [27, 28, 30, 32, 33, 36, 44]],
[30, T("Afghanistan"), 5, 466, 117, [16, 28, 29, 31, 32]],
[31, T("Middle East"), 5, 427, 179, [16, 22, 30, 32, 20]],
[32, T("United Indiastan"), 5, 511, 189, [29, 30, 31, 33, 53]],
[33, T("Angkhor Wat"), 5, 577, 207, [29, 32, 39]],
[34, T("Sakha"), 5, 580, 23, [27, 35, 38]],
[35, T("Alden"), 5, 570, 70, [27, 34, 36, 38]],
[36, T("Khan Industrial State"), 5, 577, 107, [29, 35, 37, 38, 27]],
[37, T("Japan"), 5, 650, 114, [36, 38, 44]],
[38, T("Pevek"), 5, 630, 26, [1, 34 .. 37]],
[39, T("Java Cartel"), 6, 605, 270, [33, 41, 40, 43]],
[40, T("New Guinea"), 6, 660, 284, [39, 41, 42]],
[41, T("Aboriginal League"), 6, 595, 365, [39, 40, 42, 55]],
[42, T("Australian Testing Ground"), 6, 650, 352, [40, 41]],
[43, T("Sung Tzu"), 8, 652, 228, [39, 44]],
[44, T("Neo Tokyo"), 8, 648, 172, [29, 37, 43, 47]],
[45, T("Poseidon"), 7, 31, 88, [7, 46]],
[46, T("Hawaiian Preserve"), 7, 33, 145, [45, 47]],
[47, T("New Atlantis"), 7, 49, 198, [10, 44, 46]],
[48, T("Western Ireland"), 9, 217, 133, [17, 49]],
[49, T("New York"), 9, 163, 159, [8, 48, 50]],
[50, T("Nova Brasilia"), 9, 187, 212, [12, 49]],
[51, T("Neo Paulo"), 10, 206, 307, [12, 52]],
[52, T("The Ivory Reef"), 10, 269, 293, [21, 51]],
[53, T("South Ceylon"), 11, 483, 268, [32, 54]],
[54, T("Microcorp"), 11, 473, 327, [26, 53, 55]],
[55, T("Akara"), 11, 527, 359, [41, 54]],
);
}


sub _raw_cards {
return (
# type, id_country
#   artillery, 2
#   wildcard
["infantry", 1],
["artillery", 2],
["infantry", 3],
["infantry", 4],
["cavalry", 5],
["cavalry", 6],
["cavalry", 7],
["artillery", 8],
["artillery", 9],
["artillery", 10],
["cavalry", 11],
["artillery", 12],
["infantry", 13],
["infantry", 14],
["artillery", 15],
["artillery", 16],
["cavalry", 17],
["cavalry", 18],
["infantry", 19],
["cavalry", 20],
["infantry", 21],
["infantry", 22],
["cavalry", 23],
["artillery", 24],
["artillery", 25],
["infantry", 26],
["artillery", 27],
["cavalry", 28],
["cavalry", 29],
["infantry", 30],
["artillery", 31],
["infantry", 32],
["artillery", 33],
["cavalry", 34],
["infantry", 35],
["artillery", 36],
["infantry", 37],
["cavalry", 38],
["cavalry", 39],
["cavalry", 40],
["artillery", 41],
["infantry", 42],
["artillery", 43],
["artillery", 44],
["infantry", 45],
["artillery", 46],
["cavalry", 47],
["cavalry", 48],
["infantry", 49],
["artillery", 50],
["infantry", 51],
["artillery", 52],
["cavalry", 53],
["infantry", 54],
["infantry", 55],
["joker", undef],
["joker", undef],
);
}

sub _raw_missions {
return (
# id player to destroy, nb coutnry to occupy + min armies, 3 x id of continents to occupy, description
#   0, 0,0,5,2,0,T("Conquer the continents of ASIA and SOUTH AMERICA.")
#   0, 0,0,3,6,*,T("Conquer the continents of EUROPE and AUSTRALIA and a third continent of your choice.")
#   0,18,2,0,0,0,T("Occupy 18 countries of your choice and occupy each with at least 2 armies.")
#   0,24,1,0,0,0,T("Occupy 24 countries of your choice and occupy each with at least 1 army.")
#   1,24,1,0,0,0,T("Destroy all of PLAYER1's TROOPS. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries.")
[  0,  0,  0,  5,  2,  0,  T("Conquer the continents of Asia and South America."),],
[  0,  0,  0,  3,  6,  "*",  T("Conquer the continents of Europe and Australia and a third continent of your choice."),],
[0, 0, 0, 5, 4, 0, T("Conquer the continents of Asia and Africa.")],
[  0,  0,  0,  3,  2,  "*",  T("Conquer the continents of Europe and South America and a third continent of your choice."),],
[  0,  0,  0,  1,  6,  0,  T("Conquer the continents of North America and Australia."),],
[  0,  0,  0,  1,  4,  0,  T("Conquer the continents of North America and Africa."),],
[  0,  18,  2,  0,  0,  0,  T("Occupy 18 countries of your choice and occupy each with at least 2 armies."),],
[  0,  24,  1,  0,  0,  0,  T("Occupy 24 countries of your choice and occupy each with at least 1 army."),],
[  1,  24,  1,  0,  0,  0,  T("Destroy all of Player1's Troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  2,  24,  1,  0,  0,  0,  T("Destroy all of Player2's Troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  3,  24,  1,  0,  0,  0,  T("Destroy all of Player3's Troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  4,  24,  1,  0,  0,  0,  T("Destroy all of Player4's Troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  5,  24,  1,  0,  0,  0,  T("Destroy all of Player5's Troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  6,  24,  1,  0,  0,  0,  T("Destroy all of Player6's Troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;


=pod

=head1 NAME

Games::Risk::Map::Risk2210 - Risk 2210AD map

=head1 VERSION

version 3.112590

=head1 DESCRIPTION

Risk 2210 Map by Matthias Kuehl.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__

