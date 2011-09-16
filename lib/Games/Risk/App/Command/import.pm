#
# This file is part of Games-Risk
#
# This software is Copyright (c) 2008 by Jerome Quelin.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#
use 5.014;
use strict;
use warnings;

package Games::Risk::App::Command::import;
{
  $Games::Risk::App::Command::import::VERSION = '3.112590';
}
# ABSTRACT: import a map designed for other risk games

use Data::Dump  qw{ dumpf };
use File::Copy  qw{ copy };
use Path::Class 0.22; # basename

use Games::Risk::App -command;
use Games::Risk::Logger qw{ debug };
use Games::Risk::Utils  qw{ $SHAREDIR };


# -- public methods

sub description { 'Import a Risk map designed for other Risk games.'; }

sub opt_spec {
    my $self = shift;
    return (
        [],
        [ "input|i=s"    => "path to the input map", {required=>1} ],
        [ "module|m=s"   => "path to the module"          ],
        [ "sharedir|s=s" => "path to the share directory" ],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $mapsdir  = dir( qw{ share maps } );
    my $template = $mapsdir->file( "template" );

    my $file   = file($opts->{input});
    my $mapdir = $file->parent;
    debug( "parsing map: $file\n" );
    my $map = lc( $file->basename ); $map =~ s/\..*$//;

    # find module name if needed
    my $modname = exists $opts->{module} ? $opts->{module} : ucfirst($map);
    my $module = file( qw{ lib Games Risk Map }, $modname . ".pm" );
    debug( " - module name will be: $modname ($module)\n" );
    $module->remove;

    # find share directory if needed
    my $sharedir = exists $opts->{sharedir}
        ? dir( $opts->{sharedir} )
        : $mapsdir->subdir( $map );
    debug( " - map share directory: $sharedir\n" );
    $sharedir->rmtree;
    $sharedir->mkpath;

    # parse map file
    my ($author, $title, $greyscale, $background, $cardfile, @continents, @countries);
    {{{
    debug( "parsing map file\n" );
    my @lines = $file->slurp;
    my $content = $file->slurp =~ s/\r/\n/gr;
    $author = ( $content =~ /made\s+by\s+(.*)/i )
        ? $1
        : $lines[0] =~ s/^;\s*(.*?)[\r\n]/$1/r;
    chomp $author;

    my ($section, $noline, $id_continent);
    foreach my $line ( @lines ) {
        $noline++;
        $line =~ s/[\r\n]//g;  # remove all end of lines
        $line =~ s/^\s+//;     # trim heading whitespaces
        $line =~ s/\s+$//;     # trim trailing whitespaces
        given ($line) {
            when (/^\s*$/)    { } # empty lines
            when (/^\s*[#;]/) { } # comments

            when (/^\[([^]]+)\]$/) {
                # changing [section]
                $section = $1;
            }

            #
            given ($section) {
                when ( undef ) {
                    given ($line) {
                        when ( /^name\s+(.*)$/ ) {
                            $title = $1;
                            debug( " - map title $title\n" );
                        }
                        default {
                            debug( "parse error [head]:$noline\t- line was: '$line'\n" );
                        }
                    }
                }
                when ( "files" ) {
                    given ($line) {
                        when ( /^map\s+(.*)$/ ) {
                            $greyscale = $mapdir->file($1);
                            debug( " - greyscale:  $greyscale\n" );
                        }
                        when ( /^pic\s+(.*)$/ ) {
                            $background = $mapdir->file($1);
                            debug( " - background: $background\n" );
                        }
                        when ( /^crd\s+(.+)$/ ) {
                            $cardfile = $mapdir->file($1);
                            debug( " - cardfile:   $cardfile\n" );
                        }
                        when ( /^prv\s+/ ) { } # preview, not needed
                        default {
                            debug( "parse error [files]:$noline\t- line was: '$line'\n" );
                        }
                    }
                }
                when ( "continents" ) {
                    # get continent params
                    $id_continent++;
                    my ($name, $bonus, $color) = split /\s+/, $line;
                    $name =~ s/[-_]/ /g;
                    push @continents, [ $id_continent, $name, $bonus, $color ];
                }
                when ( "countries" ) {
                    # get country param
                    my ($greyval, $name, $idcont, $x, $y) = split /\s+/, $line;
                    $name =~ s/[-_]/ /g;
                    debug( "parse error [countries]:$noline\t- continent $idcont does not exist\n" ), break
                        if $idcont > $id_continent;
                    debug( "parse error [countries]:$noline\t- country $greyval already exists\n" ), break
                        if grep { $_->[0] == $greyval } @countries;
                    push @countries, [ $greyval, $name, $idcont, $x, $y ];
                }

                when ( "borders" ) {
                    my ($id, @neighbours) = split /\s+/, $line;
                    my ($country) = grep { $_->[0] == $id } @countries;
                    debug( "parse error [borders]:$noline - country $id doesn't exist" ), break
                        unless defined $country;
                    push @$country, \@neighbours;
                }

                default {
                    debug( "parse error: how to parse $section?\n" );
                }
            }
        }
    }
    }}}
    my $name = lc $modname;
    $title //= $modname;
    debug( " - found ". scalar(@continents). " continents\n" );
    debug( " - found ". scalar(@countries). " countries\n" );

    # parse card file
    my (@cards, @missions);
    {{{
    debug( "parsing card file\n" );
    my @lines = $cardfile->slurp;
    my ($section, $noline);
    foreach my $line ( @lines ) {
        $noline++;
        $line =~ s/[\r\n]//g;  # remove all end of lines
        $line =~ s/^\s+//;     # trim heading whitespaces
        $line =~ s/\s+$//;     # trim trailing whitespaces
        given ($line) {
            when (/^\s*$/)    { } # empty lines
            when (/^\s*[#;]/) { } # comments

            when (/^\[([^]]+)\]$/) {
                # changing [section]
                $section = $1;
            }

            #
            given ($section) {
                when ( undef ) {
                    debug( "parse error [head]:$noline\t- line was: '$line'\n" );
                }
                when ( "cards" ) {
                    my ($type, $id) = split /\s+/, lc $line;
                    $type = 'artillery' if $type eq 'cannon';
                    $type = 'joker'     if $type eq 'wildcard';
                    push @cards, [ $type, $id ];
                }
                when ( "missions" ) {
                    my ($player, $nbc, $armies, $idc1, $idc2, $idc3, $descr) =  split /\s+/, $line, 7;
                    $descr =~ s/([A-Z]+)/ucfirst lc $1/ge;
                    push @ missions, [$player, $nbc, $armies, $idc1, $idc2, $idc3, $descr];
                }
                default {
                    debug( "parse error: how to parse $section?\n" );
                }
            }
        }
    }
    }}}
    debug( " - found ". scalar(@cards). " cards\n" );
    debug( " - found ". scalar(@missions). " missions\n" );

    # prepare template replacements
    my $continents = join "\n", map { _as_code($_) } @continents;
    my $countries  = join "\n", map { _as_code($_) } @countries;
    my $cards      = join "\n", map { _as_code($_) } @cards;
    my $missions   = join "\n", map { _as_code($_) } @missions;

    my $code = $template->slurp;
    $code =~ s/__MODULE_NAME__/$modname/g;
    $code =~ s/__MAP_NAME__/$name/g;
    $code =~ s/__MAP_TITLE__/$title/g;
    $code =~ s/__MAP_AUTHOR__/$author/g;
    $code =~ s/__MAP_CONTINENTS__/$continents/g;
    $code =~ s/__MAP_COUNTRIES__/$countries/g;
    $code =~ s/__MAP_CARDS__/$cards/g;
    $code =~ s/__MAP_MISSIONS__/$missions/g;

    #
    debug( "creating module for map\n" );
    my $fh = $module->openw;
    $fh->print( $code );
    $fh->close;

    my $bg = $sharedir->file( $background =~ s/^([^.]+)/background/r );
    my $gs = $sharedir->file( $greyscale  =~ s/^([^.]+)/greyscale/r );
    debug( "copying background to $bg\n" );
    debug( "copying greyscale  to $gs\n" );
    copy( $background, $bg->stringify );
    copy( $greyscale,  $gs->stringify );
}

sub _as_code {
    my $what = shift;
    my $code = dumpf( $what, sub {
        my($ctx, $ref) = @_;
        return unless $ctx->is_scalar;
        return unless defined $$ref;
        return unless $$ref =~ /^[A-Z]/;
        return { dump => qq{T("$$ref")} };
    } );
    $code =~ s/\n//g;
    return "$code,";
}

1;


=pod

=head1 NAME

Games::Risk::App::Command::import - import a map designed for other risk games

=head1 VERSION

version 3.112590

=head1 DESCRIPTION

This command transforms a map designed for another Risk game to a Perl
module that can be used by C<prisk>.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__


