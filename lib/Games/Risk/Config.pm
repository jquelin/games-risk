use 5.010;
use strict;
use warnings;

package Games::Risk::Config;
# ABSTRACT: prisk configuration

use Exporter::Lite;
use File::HomeDir::PathClass  qw{ my_dist_config };
use MooseX::Singleton;  # should come before any other moose
use MooseX::Has::Sugar;
use Readonly;
use YAML::Tiny                qw{ DumpFile LoadFile };

use Games::Risk::Logger       qw{ debug };

our @EXPORT_OK = qw{ $CONFIG };
our $CONFIG    = __PACKAGE__->instance;

# FIXME - 20110830 - quiet moosex::singleton warning
# cf https://rt.cpan.org/Ticket/Display.html?id=46086
{ no warnings; $Games::Risk::Config::singleton; }


# -- attributes

has file  => ( ro, isa => 'Path::Class::File', lazy_build );
has _hash => ( rw, isa => 'HashRef', lazy_build );


# --  initializer

sub _build_file {
    my $configdir  = my_dist_config( "Games-Risk", { create=>1 } );
    return $configdir->file( "config.yaml" );
}

sub _build__hash {
    my $self = shift;
    my $file = $self->file;
    debug( "loading $file\n" );
    my $yaml = eval { LoadFile( $file ) };
    return $@ ? {} : $yaml;
}

# -- methods

=method save

    $config->save;

Save C<$config> to its on-disk file.

=cut

sub save {
    my $self = shift;
    my $file = $self->file;
    my $hash = $self->_hash;
    $hash->{meta} = {
        schema_version => 1
    };
    debug( "saving configuration to $file\n" );
    eval { DumpFile( $file->stringify, $self->_hash ) };
    debug($@) if $@;
}


=method get

    my $value = $config->get( $key );

Return the C<$value> associated to C<$key> in C<$config>.

=cut

sub get {
    my ($self, $key) = @_;
    my $hash = $self->_hash;
    $hash = $hash->{ $_ } for split /\./, $key;
    return $hash;
}


=method set

    $config->set( $key, $value );

Associate a given C<$value> to a C<$key> in C<$config>.

=cut

sub set {
    my ($self, $key, $val) = @_;
    my $hash = $self->_hash;
    eval '$hash->{' . join( "}{", split /\./, $key ) . '} = $val';
}


1;
__END__

=head1 SYNOPSIS

    use Games::Risk::Config;
    my $config = Games::Risk::Config->instance;
    my $val = $config->get( "foo.bar.baz" );
    $config->set( "foo.bar.baz", 42 );
    $config->save;


=head1 DESCRIPTION

This module implements a basic persistant configuration. The
configuration is storead as YAML, yet keys are flattened using dots -
eg, a C<foo.bar.baz> key will fetch at depth 3.

