#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Model;

use 5.010;
use strict;
use warnings;

use File::Basename qw{ fileparse };
use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ dirname background } );

#--
# Subs

# -- public subs

sub load_file {
    my ($self, $file) = @_;

    my (undef, $dirname, undef) = fileparse($file);
    $self->dirname( $dirname );
    say $self->dirname;

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
            chomp $line;
            my $meth = "_parse_file_section_$section";
            my $rv = $self->$meth($line);
            if ( $rv ) {
                my $prefix = "section [$section]:$.";
                warn "$prefix - don't know how to parse: '$line'\n";
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
    return 'wtf?';
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


