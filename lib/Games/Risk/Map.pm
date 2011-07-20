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

package Games::Risk::Map;
BEGIN {
  $Games::Risk::Map::VERSION = '3.112010';
}
# ABSTRACT: map being played

use File::Basename qw{ fileparse };
use List::Util      qw{ shuffle };
use List::MoreUtils qw{ uniq };
use aliased 'Games::Risk::Card';
use aliased 'Games::Risk::Continent';
use aliased 'Games::Risk::Country';

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ background _cards greyscale _continents _countries _dirname } );

my $id_continent;


#--
# METHODS

# -- public methods

#
# $map->destroy;
#
# Break all circular references in $map, to reclaim all continents and
# countries objects.
#
sub destroy {
    my ($self) = @_;

    $_->destroy for @{ $self->_cards };
    $_->destroy for $self->continents;
    $_->destroy for $self->countries;

    $self->_cards([]);
    $self->_continents([]);
    $self->_countries([]);
}


#
# my $card = $map->card_get;
#
# Return the next card from the card stack.
#
sub card_get {
    my ($self) = @_;

    # get a card from the stack
    my ($card, @cards) = @{ $self->_cards };
    $self->_cards( \@cards );

    return $card;
}


#
# $map->card_return( $card );
#
# Push back $card in the card stack.
#
sub card_return {
    my ($self, $card) = @_;

    my @cards = ( @{ $self->_cards }, $card );
    $self->_cards( \@cards );
}


#
# my @continents = $map->continents;
#
# Return the list of all continents in the $map.
#
sub continents {
    my ($self) = @_;
    return values %{ $self->_continents };
}


#
# my @owned = $map->continents_owned;
#
# Return a list with all continents that are owned by a single player.
#
sub continents_owned {
    my ($self) = @_;

    my @owned = ();
    foreach my $continent ( $self->continents ) {
        my $nb = uniq map { $_->owner } $continent->countries;
        push @owned, $continent if $nb == 1;
    }

    return @owned;
}


#
# my @countries = $map->countries;
#
# Return the list of all countries in the $map.
#
sub countries {
    my ($self) = @_;
    return values %{ $self->_countries };
}


#
# my $country = $map->country_get($id);
#
# Return the country which id matches $id.
#
sub country_get {
    my ($self, $id) = @_;
    my ($country) = grep { $_->id == $id } $self->countries;
    return $country;
}


sub load_file {
    my ($self, $file) = @_;

    my (undef, $dirname, undef) = fileparse($file);
    $self->_dirname( $dirname );
    $self->_continents({});
    $self->_countries({});
    $id_continent = 0; # reset continent id

    open my $fh, '<', $file; # FIXME: error handling
    my $section = '';
    while ( defined( my $line = <$fh> ) ) {
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

            # further parsing
            my $meth = "_parse_file_section_$section";
            my $rv = $self->$meth($line);
            if ( $rv ) {
                warn "parse error [$section]:$. $rv \t- line was: '$line'\n";
                # FIXME: error handling
            }
        }
    }

    # update the cards with the correct country
    foreach my $card ( @{ $self->_cards } ) {
        my $id = $card->country;
        next unless defined $id;
        my $country = $self->country_get($id);
        if ( not defined $country ) {
            warn "cards parse error: country $id doesn't exist\n";
            next;
        }
        $card->country( $country );
    }

    #use Data::Dumper; say Dumper($self);
    #use YAML; say Dump($self);
}

#--
# SUBROUTINES

# -- private subs

# FIXME: the following are UGLY, UGLY, UGLY!

sub _parse_file_section_ {
    my ($self) = @_;
    return 'wtf?';
}

sub _parse_file_section_borders {
    my ($self, $line) = @_;
    my ($id, @neighbours) = split /\s+/, $line;
    my $country = $self->country_get($id);
    return "country $id doesn't exist" unless defined $country;
    foreach my $n ( @neighbours ) {
        my $neighbour = $self->country_get($n);
        return "country $n doesn't exist" unless defined $neighbour;
        $country->neighbour_add($neighbour);
    }
    return;
}

sub _parse_file_section_continents {
    my ($self, $line) = @_;

    # get continent params
    $id_continent++;
    my ($name, $bonus, undef) = split /\s+/, $line;
    $name =~ s/[-_]/ /g;

    # create and store continent
    my $continent = Continent->new({id=>$id_continent, name=>$name, bonus=>$bonus});
    $self->_continents->{ $id_continent } = $continent;

    return;
}

sub _parse_file_section_countries {
    my ($self, $line) = @_;

    # get country param
    my ($greyval, $name, $idcont, $x, $y) = split /\s+/, $line;
    $name =~ s/[-_]/ /g;
    my $continent = $self->_continents->{$idcont};
    return "continent '$idcont' does not exist" unless defined $continent;

    # create and store country
    my $country = Country->new({
        greyval   => $greyval,
        name      => $name,
        continent => $continent,
        coordx    => $x,
        coordy    => $y
    });
    $self->_countries->{ $greyval } = $country;

    # add cross-references
    $continent->add_country($country);

    return;
}

sub _parse_file_section_files {
    my ($self, $line) = @_;
    given ($line) {
        when (/^map\s+(.*)$/) {
            $self->greyscale( $self->_dirname . "/$1" );
            return;
        }
        when (/^pic\s+(.*)$/) {
            $self->background( $self->_dirname . "/$1" );
            return;
        }
        when(/^crd\s+(.+)$/) {
            my $file = $self->_dirname . "/$1";
            open my $fh, '<', $file or die "cannot open '$file': $!";

            my $section = '';
            my @cards;
            while ( defined( my $l = <$fh> ) ) {
                $l =~ s/[\r\n]//g;  # remove all end of lines
                $l =~ s/^\s+//;     # trim heading whitespaces
                $l =~ s/\s+$//;     # trim trailing whitespaces

                given ($l) {
                    when (/^\s*$/)    { } # empty lines
                    when (/^\s*[#;]/) { } # comments

                    when (/^\[([^]]+)\]$/) {
                        # changing [section]
                        $section = $1;
                    }

                    # further parsing
                    if ( $section eq 'cards' ) {
                        my ($type, $id) = split /\s+/, lc $l;
                        $type = 'artillery' if $type eq 'cannon';
                        $type = 'joker'    if $type eq 'wildcard';
                        push @cards, Card->new({ type=>$type, country=>$id });
                    }

                    # FIXME: parsing missions too in the same file
                }
            }
            close $fh;
            $self->_cards( [ shuffle @cards ] );
            return;
        }
        return 'wtf?';
    }
}

1;



=pod

=head1 NAME

Games::Risk::Map - map being played

=head1 VERSION

version 3.112010

=head1 SYNOPSIS

    my $id = Games::Risk::Map->new(\%params);

=head1 DESCRIPTION

This module implements a map, pointing to the continents, the
countries, etc. of the game currently in play.

=head1 METHODS

=head2 Constructor

=over 4

=item * my $player = Games::Risk::Map->new( \%params )

=back

=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Map> objects:

=over 4

=item * background()

the path to the background image for the board.

=item * greyscale()

the path to the greyscale bitmap for the board.

=back

=head2 Object methods

=over 4

=item * $map->destroy()

Break all circular references in C<$map>, to prevent memory leaks.

=item * my $card = $map->card_get()

Return the next card from the cards stack.

=item * $map->card_return( $card )

Push back a $card in the card stack.

=item * my @continents = $map->continents()

Return the list of all continents in the C<$map>.

=item * my @owned = $map->continents_owned;

Return a list with all continents that are owned by a single player.

=item * my @countries = $map->countries()

Return the list of all countries in the C<$map>.

=item * my $country = $map->country_get($id)

Return the country which id matches C<$id>.

=item * $map->load_file( \%params )

=back

=begin quiet_pod_coverage

=item Card (inserted by aliased)

=item Continent (inserted by aliased)

=item Country (inserted by aliased)

=end quiet_pod_coverage

=head1 SEE ALSO

L<Games::Risk>.

=head1 AUTHOR

Jerome Quelin

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2008 by Jerome Quelin.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__



