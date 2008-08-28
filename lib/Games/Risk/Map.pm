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

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ dirname background continents } );


#--
# SUBROUTINES

# -- public subs

sub load_file {
    my ($self, $file) = @_;

    my (undef, $dirname, undef) = fileparse($file);
    $self->dirname( $dirname );
    $self->continents({});

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
    $self->continents->{ $id } = $continent;

    return;
}

sub _parse_file_section_countries {
    my ($self, $line) = @_;
    return 'wtf?';
}

sub _parse_file_section_files {
    my ($self, $line) = @_;
    given ($line) {
        when (/^pic\s+(.*)$/) {
            $self->background( $self->dirname . "/$1" );
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



=head2 Object methods

=over 4

=item * $map->load_file( \%params )

=back



=begin quiet_pod_coverage

=item Continent (inserted by aliased)

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

