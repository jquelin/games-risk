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

package Games::Risk::Map::Godstorm;
{
  $Games::Risk::Map::Godstorm::VERSION = '3.112590';
}
# ABSTRACT: Risk GodStorm

use Moose;
use Games::Risk::I18n qw{ T };
extends 'Games::Risk::Map';


# -- map  builders

sub name   { "godstorm" }
sub title  { T("Risk GodStorm") }
sub author { "Yura Mamyrin" }


# -- raw map information

sub _raw_continents {
return (
# id, name, bonus, color
#   0, T('Europe'), 5, blue
[1, T("Germania"), 5, "green"],
[2, T("Atlantis"), 3, "magenta"],
[3, T("Asia Minor"), 3, "cyan"],
[4, T("Africa"), 5, "yellow"],
[5, T("Europa"), 7, "red"],
[6, T("Hyrkania"), 2, "orange"],
);
}

sub _raw_countries {
return (
# greyscale, name, continent id, x, y, [connections]
#   1, T('Alaska'), 1, 43, 67, [ 1,2,3,38 ]
[1, T("Dacia"), 5, 355, 175, [40, 2, 3]],
[2, T("Thracia"), 5, 403, 196, [1, 3, 9]],
[3, T("Dalmatia"), 5, 316, 214, [1, 4, 2, 9, 6]],
[4, T("Liguria"), 5, 265, 229, [3, 20, 5]],
[5, T("Roma"), 5, 294, 287, [4, 7, 6]],
[6, T("Apulia"), 5, 327, 300, [5, 8, 9, 3]],
[7, T("Corsica"), 5, 259, 310, [5]],
[8, T("Sicilia"), 5, 343, 347, [23, 6]],
[9, T("Graecia"), 5, 401, 263, [3, 6, 10, 11, 2]],
[10, T("Minoa"), 5, 445, 290, [9, 27, 11]],
[11, T("Ionia"), 5, 476, 218, [9, 12, 10]],
[12, T("Anatolia"), 5, 540, 177, [11, 32]],
[13, T("Hibernia"), 1, 86, 169, [15, 14, 35]],
[14, T("Caledonia"), 1, 142, 135, [13, 16, 15]],
[15, T("Anglia"), 1, 142, 184, [19, 20, 13, 14]],
[16, T("Thule"), 1, 210, 78, [17, 19, 14]],
[17, T("Varangia"), 1, 314, 16, [18, 16, 39]],
[18, T("Galicia"), 1, 330, 90, [19, 17]],
[19, T("Alemannia"), 1, 231, 189, [20, 18, 16, 15]],
[20, T("Gaul"), 1, 188, 258, [21, 19, 15, 4]],
[21, T("Iberia"), 1, 148, 343, [20, 38, 22]],
[22, T("Atlas"), 4, 173, 404, [38, 21, 24, 23]],
[23, T("Carthage"), 4, 290, 361, [22, 24, 25, 8]],
[24, T("Gaitulia"), 4, 257, 409, [22, 23, 25, 26]],
[25, T("Cyrenaica"), 4, 386, 375, [23, 24, 26, 27]],
[26, T("Nubia"), 4, 447, 410, [25, 27, 24, 28]],
[27, T("Egypt"), 4, 517, 365, [25, 26, 28, 32, 10]],
[28, T("Kush"), 4, 583, 398, [27, 34, 26]],
[29, T("Parthia"), 3, 648, 154, [31, 30, 42]],
[30, T("Sumer"), 3, 667, 234, [33, 29, 31]],
[31, T("Assyria"), 3, 611, 231, [33, 32, 29, 30]],
[32, T("Phoenicia"), 3, 545, 267, [27, 34, 33, 31, 12]],
[33, T("Babylon"), 3, 614, 283, [34, 32, 31, 30]],
[34, T("Sheba"), 3, 631, 359, [28, 32, 33]],
[35, T("Hesperide"), 2, 37, 245, [13, 36]],
[36, T("Tritonis"), 2, 35, 306, [35, 37]],
[37, T("Poseidonis"), 2, 18, 371, [36, 38]],
[38, T("Oricalcos"), 2, 55, 412, [37, 22, 21]],
[39, T("Rus"), 6, 475, 39, [42, 41, 40, 17]],
[40, T("Scythia"), 6, 422, 103, [41, 39, 1]],
[41, T("Cimmeria"), 6, 512, 91, [42, 39, 40]],
[42, T("Sarmathia"), 6, 621, 67, [29, 39, 41]],
);
}


sub _raw_cards {
return (
# type, id_country
#   artillery, 2
#   wildcard
["cavalry", 1],
["infantry", 2],
["artillery", 3],
["cavalry", 4],
["infantry", 5],
["artillery", 6],
["cavalry", 7],
["infantry", 8],
["artillery", 9],
["cavalry", 10],
["infantry", 11],
["artillery", 12],
["cavalry", 13],
["infantry", 14],
["artillery", 15],
["cavalry", 16],
["infantry", 17],
["artillery", 18],
["cavalry", 19],
["infantry", 20],
["artillery", 21],
["cavalry", 22],
["infantry", 23],
["artillery", 24],
["cavalry", 25],
["infantry", 26],
["artillery", 27],
["cavalry", 28],
["infantry", 29],
["artillery", 30],
["cavalry", 31],
["infantry", 32],
["artillery", 33],
["cavalry", 34],
["infantry", 35],
["artillery", 36],
["cavalry", 37],
["infantry", 38],
["artillery", 39],
["cavalry", 40],
["infantry", 41],
["artillery", 42],
["joker", undef],
["joker", undef],
["joker", undef],
["joker", undef],
["joker", undef],
["joker", undef],
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
[  0,  0,  0,  5,  2,  0,  T("Conquer the continents of Europa and Atlantis."),],
[  0,  0,  0,  3,  6,  "*",  T("Conquer the continents of Asia Minor and Hyrkania and a third continent of your choice."),],
[  0,  0,  0,  5,  4,  0,  T("Conquer the continents of Europa and Africa."),],
[  0,  0,  0,  3,  2,  "*",  T("Conquer the continents of Asia Minor and Atlantis and a third continent of your choice."),],
[  0,  0,  0,  1,  6,  0,  T("Conquer the continents of Germania and Hyrkania."),],
[  0,  0,  0,  1,  4,  0,  T("Conquer the continents of Germania and Africa."),],
[  0,  18,  2,  0,  0,  0,  T("Occupy 18 countries of your choice and occupy each with at least 2 armies."),],
[  0,  24,  1,  0,  0,  0,  T("Occupy 24 countries of your choice and occupy each with at least 1 army."),],
[  1,  24,  1,  0,  0,  0,  T("Destroy all of Player1's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  2,  24,  1,  0,  0,  0,  T("Destroy all of Player2's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  3,  24,  1,  0,  0,  0,  T("Destroy all of Player3's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  4,  24,  1,  0,  0,  0,  T("Destroy all of Player4's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  5,  24,  1,  0,  0,  0,  T("Destroy all of Player5's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
[  6,  24,  1,  0,  0,  0,  T("Destroy all of Player6's troops. If they are yours or they have already been destroyed by another player then your mission is: Occupy 24 countries."),],
);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;


=pod

=head1 NAME

Games::Risk::Map::Godstorm - Risk GodStorm

=head1 VERSION

version 3.112590

=head1 DESCRIPTION

Risk GodStorm by Yura Mamyrin.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__

