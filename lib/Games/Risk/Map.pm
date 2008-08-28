#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Map;

use 5.010;
use strict;
use warnings;

use File::Basename qw{ fileparse };
use aliased 'Games::Risk::Map::Continent';
use aliased 'Games::Risk::Map::Country';

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ background _continents _countries _dirname } );


#--
# SUBROUTINES

# -- public subs

#
# my @countries = $map->countries;
#
# Return the list of all countries in the $map.
#
sub countries {
    my ($self) = @_;
    return values %{ $self->_countries };
}


sub load_file {
    my ($self, $file) = @_;

    my (undef, $dirname, undef) = fileparse($file);
    $self->_dirname( $dirname );
    $self->_continents({});
    $self->_countries({});

    open my $fh, '<', $file; # FIXME: error handling
    my $section = '';
    while ( defined( my $line = <$fh> ) ) {
        given ($line) {
            when (/^\s*$/)    { } # empty lines
            when (/^\s*[#;]/) { } # comments

            when (/^\[([^]]+)\]$/) {
                # changing [section]
                $section = $1;
            }

            # further parsing
            $line =~ s/[\r\n]//g;  # remove all end of lines
            $line =~ s/^\s+//;     # trim heading whitespaces
            $line =~ s/\s+$//;     # trim trailing whitespaces
            my $meth = "_parse_file_section_$section";
            my $rv = $self->$meth($line);
            if ( $rv ) {
                warn "parse error [$section]:$. $rv\n";
                warn "line was:  '$line'\n";
                # FIXME: error handling
            }
        }
    }

    #use Data::Dumper; say Dumper($self);
    #use YAML; say Dump($self);
}

# -- private subs

sub _parse_file_section_ {
    my ($self, $line) = @_;
    return 'wtf?';
}

sub _parse_file_section_borders {
    my ($self, $line) = @_;
    return 'wtf?';
}

sub _parse_file_section_continents {
    my ($self, $line) = @_;
    state $id = 0;

    # get continent params
    $id++;
    my ($name, $bonus, undef) = split /\s+/, $line;

    # create and store continent
    my $continent = Continent->new({id=>$id, name=>$name, bonus=>$bonus});
    $self->_continents->{ $id } = $continent;

    return;
}

sub _parse_file_section_countries {
    my ($self, $line) = @_;

    # get country param
    my ($greyval, $name, $idcont, $x, $y) = split /\s+/, $line;
    my $continent = $self->_continents->{$idcont};
    return "continent '$idcont' does not exist" unless defined $continent;

    # create and store country
    my $country = Country->new({
        greyval   => $greyval,
        name      => $name,
        continent => $continent,
        x         => $x,
        y         => $y
    });
    $self->_countries->{ $greyval } = $country;

    # add cross-references
    $continent->add_country($country);

    return;
}

sub _parse_file_section_files {
    my ($self, $line) = @_;
    given ($line) {
        when (/^pic\s+(.*)$/) {
            $self->background( $self->_dirname . "/$1" );
            return;
        }
        return 'wtf?';
    }
}

1;

__END__



=head1 NAME

Games::Risk::Map - map being played



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


=back


=head2 Object methods

=over 4

=item * my @countries = $map->countries()

Return the list of all countries in the C<$map>.


=item * $map->load_file( \%params )

=back



=begin quiet_pod_coverage

=item Continent (inserted by aliased)

=item Country (inserted by aliased)

=end quiet_pod_coverage



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

