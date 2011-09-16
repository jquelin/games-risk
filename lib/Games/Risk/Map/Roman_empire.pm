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

package Games::Risk::Map::Roman_empire;
{
  $Games::Risk::Map::Roman_empire::VERSION = '3.112590';
}
# ABSTRACT: Roman Empire map

use Moose;
use Games::Risk::I18n qw{ T };
extends 'Games::Risk::Map';


# -- map  builders

sub name   { "roman_empire" }
sub title  { T("Roman Empire") }
sub author { "Adrien Schvalberg" }


# -- raw map information

sub _raw_continents {
return (
# id, name, bonus, color
#   0, T('Europe'), 5, blue
[1, T("Africa"), 3, "blue"],
[2, T("Asia"), 5, "magenta"],
[3, T("Gallia"), 4, "yellow"],
[4, T("Hispania"), 2, "green"],
[5, T("Illyrium"), 7, "red"],
[6, T("Italia"), 6, "cyan"],
);
}

sub _raw_countries {
return (
# greyscale, name, continent id, x, y, [connections]
#   1, T('Alaska'), 1, 43, 67, [ 1,2,3,38 ]
[1, T("Aegyptus"), 1, 466, 403, [3, 6, 12]],
[2, T("Africa proconsularis"), 1, 239, 303, [3, 4, 5, 44]],
[3, T("Cyrenaica"), 1, 368, 366, [1, 2]],
[4, T("Numidia inf."), 1, 217, 297, [2, 5]],
[5, T("Numidia sup."), 1, 203, 323, [2, 4, 27]],
[6, T("Arabia"), 2, 526, 386, [1, 12, 15]],
[7, T("Bithynia"), 2, 490, 239, [10, 13, 14, 37]],
[8, T("Cappadocia"), 2, 538, 263, [9, 10, 14, 15]],
[9, T("Cilicia"), 2, 520, 304, [8, 10, 11, 12, 15]],
[10, T("Galatia"), 2, 508, 271, [7, 8, 9, 11, 13, 14]],
[11, T("Lycia"), 2, 490, 287, [9, 10, 13]],
[12, T("Palestina"), 2, 537, 354, [1, 6, 9, 15]],
[13, T("Phrygia"), 2, 463, 275, [7, 10, 11, 29, 33, 37]],
[14, T("Pontus"), 2, 548, 234, [7, 8, 10]],
[15, T("Syria"), 2, 594, 297, [6, 8, 9, 12]],
[16, T("Aquitania"), 3, 122, 182, [21, 22, 28]],
[17, T("Belgica"), 3, 171, 115, [18 .. 21]],
[18, T("Britannia"), 3, 101, 37, [17, 21]],
[19, T("Germania inf."), 3, 182, 86, [17, 20]],
[20, T("Germania sup."), 3, 205, 141, [17, 19, 21, 22, 39, 41]],
[21, T("Lugdunensis"), 3, 133, 112, [16, 17, 18, 20, 22]],
[22, T("Narbonensis"), 3, 183, 180, [16, 20, 21, 28, 38, 39]],
[23, T("Baetica"), 4, 55, 274, [26, 27, 28]],
[24, T("Baleares"), 4, 161, 240, [28]],
[25, T("Gallaecia et Asturia"), 4, 30, 219, [26, 28]],
[26, T("Lusitania"), 4, 23, 267, [23, 25, 28]],
[27, T("Mauretania"), 4, 134, 305, [5, 23]],
[28, T("Terraconensis"), 4, 99, 253, [16, 22 .. 26]],
[29, T("Achaia"), 5, 389, 280, [13, 32, 33]],
[30, T("Dacia"), 5, 403, 173, [34, 35, 36]],
[31, T("Dalmatia"), 5, 349, 206, [32, 33, 35, 36, 39, 42]],
[32, T("Epirus"), 5, 368, 251, [29, 31, 33, 42]],
[33, T("Macedonia"), 5, 392, 249, [13, 29, 31, 32, 35, 37]],
[34, T("Moesia inf."), 5, 445, 201, [30, 35, 37]],
[35, T("Moesia sup."), 5, 392, 210, [30, 31, 33, 34, 36, 37]],
[36, T("Pannonia"), 5, 334, 144, [30, 31, 35, 39, 40]],
[37, T("Thracia"), 5, 436, 228, [7, 13, 33, 34, 35]],
[38, T("Corsica"), 6, 234, 205, [22, 39, 42, 43]],
[  39,  T("Gallia Cisalpinia"),  6,  256,  162,  [20, 22, 31, 36, 38, 40, 41, 42],],
[40, T("Noricum"), 6, 287, 129, [36, 39, 41]],
[41, T("Raetia"), 6, 241, 139, [20, 39, 40]],
[42, T("Roma"), 6, 307, 236, [31, 32, 38, 39, 44]],
[43, T("Sardinia"), 6, 235, 256, [38]],
[44, T("Sicilia"), 6, 286, 274, [2, 42]],
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
["cavalry", 43],
["artillery", 44],
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
[0, 0, 0, 2, 6, 0, T("Conquer the dioceses of Asia and Italia.")],
[  0,  0,  0,  3,  4,  "*",  T("Conquer the dioceses of Gallia and Hispania and a third diocese of your choice."),],
[  0,  0,  0,  5,  1,  0,  T("Conquer the dioceses of Illyrium and Africa."),],
[  0,  0,  0,  5,  4,  "*",  T("Conquer the dioceses of Illyrium and Hispania and a third diocese of your choice."),],
[0, 0, 0, 3, 2, 0, T("Conquer the dioceses of Gallia and Asia.")],
[0, 0, 0, 6, 1, 0, T("Conquer the dioceses of Italia and Africa.")],
[  0,  14,  3,  0,  0,  0,  T("Occupy 14 provinces of your choice and occupy each with at least 3 armies."),],
[  0,  18,  2,  0,  0,  0,  T("Occupy 18 provinces of your choice and occupy each with at least 2 armies."),],
[  0,  24,  1,  0,  0,  0,  T("Occupy 24 provinces of your choice and occupy each with at least 1 army."),],
[  1,  14,  3,  0,  0,  0,  T("Destroy all of Player1's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 14 provinces with at least 3 armies."),],
[  2,  14,  3,  0,  0,  0,  T("Destroy all of Player2's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 14 provinces with at least 3 armies."),],
[  3,  14,  3,  0,  0,  0,  T("Destroy all of Player3's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 14 provinces with at least 3 armies."),],
[  4,  14,  3,  0,  0,  0,  T("Destroy all of Player4's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 14 provinces with at least 3 armies."),],
[  5,  14,  3,  0,  0,  0,  T("Destroy all of Player5's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 14 provinces with at least 3 armies."),],
[  6,  14,  3,  0,  0,  0,  T("Destroy all of Player6's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 14 provinces with at least 3 armies."),],
[  1,  18,  2,  0,  0,  0,  T("Destroy all of Player1's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 18 provinces with at least 2 armies."),],
[  2,  18,  2,  0,  0,  0,  T("Destroy all of Player2's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 18 provinces with at least 2 armies."),],
[  3,  18,  2,  0,  0,  0,  T("Destroy all of Player3's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 18 provinces with at least 2 armies."),],
[  4,  18,  2,  0,  0,  0,  T("Destroy all of Player4's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 18 provinces with at least 2 armies."),],
[  5,  18,  2,  0,  0,  0,  T("Destroy all of Player5's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 18 provinces with at least 2 armies."),],
[  6,  18,  2,  0,  0,  0,  T("Destroy all of Player6's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 18 provinces with at least 2 armies."),],
[  1,  24,  1,  0,  0,  0,  T("Destroy all of Player1's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 provinces."),],
[  2,  24,  1,  0,  0,  0,  T("Destroy all of Player2's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 provinces."),],
[  3,  24,  1,  0,  0,  0,  T("Destroy all of Player3's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 provinces."),],
[  4,  24,  1,  0,  0,  0,  T("Destroy all of Player4's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 provinces."),],
[  5,  24,  1,  0,  0,  0,  T("Destroy all of Player5's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 provinces."),],
[  6,  24,  1,  0,  0,  0,  T("Destroy all of Player6's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 provinces."),],
);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;


=pod

=head1 NAME

Games::Risk::Map::Roman_empire - Roman Empire map

=head1 VERSION

version 3.112590

=head1 DESCRIPTION

Roman Empire Map by Adrien Schvalberg.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__

