
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'File::Find' => '0',
    'File::Temp' => '0',
    'Module::Build' => '0.3601',
    'Test::More' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'classical \'risk\' board game',
  'dist_author' => [
    'Jerome Quelin'
  ],
  'dist_name' => 'Games-Risk',
  'dist_version' => '3.112010',
  'license' => 'gpl',
  'module_name' => 'Games::Risk',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Carp' => '0',
    'Class::Accessor::Fast' => '0',
    'Encode' => '0',
    'Exporter' => '0',
    'Exporter::Lite' => '0',
    'File::Basename' => '0',
    'File::ShareDir::PathClass' => '0',
    'File::Spec::Functions' => '0',
    'Find::Lib' => '0',
    'Image::Magick' => '0',
    'Image::Size' => '0',
    'List::MoreUtils' => '0',
    'List::Util' => '0',
    'Locale::TextDomain' => '0',
    'MIME::Base64' => '0',
    'Moose' => '0',
    'MooseX::Has::Sugar' => '0',
    'MooseX::POE' => '0',
    'MooseX::SemiAffordanceAccessor' => '0',
    'POE' => '0',
    'POE::Loop::Tk' => '0',
    'Path::Class' => '0',
    'Readonly' => '0',
    'Tk' => '0',
    'Tk::Balloon' => '0',
    'Tk::BrowseEntry' => '0',
    'Tk::Font' => '0',
    'Tk::JPEG' => '0',
    'Tk::PNG' => '0',
    'Tk::Pane' => '0',
    'Tk::Pod::Text' => '0',
    'Tk::Role::Dialog' => '1.101480',
    'Tk::Sugar' => '0',
    'Tk::TableMatrix' => '0',
    'UNIVERSAL::require' => '0',
    'aliased' => '0',
    'constant' => '0',
    'perl' => '5.010'
  },
  'script_files' => [
    'bin/prisk'
  ],
  'share_dir' => {
    'dist' => 'share'
  }
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
