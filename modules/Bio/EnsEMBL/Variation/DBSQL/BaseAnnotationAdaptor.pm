=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

#
# Ensembl module for Bio::EnsEMBL::Variation::DBSQL::BaseAnnotationAdaptor
#
#

=head1 NAME

Bio::EnsEMBL::DBSQL::VCFCollectionAdaptor

=head1 SYNOPSIS
=head1 DESCRIPTION

This module creates a set of objects that can read from tabix-indexed VCF files.

=head1 METHODS

=cut

use strict;
use warnings;


package Bio::EnsEMBL::Variation::DBSQL::BaseAnnotationAdaptor;

use JSON;
use Cwd;
use Net::FTP;
use URI;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Bio::EnsEMBL::Variation::VCFCollection;
use Bio::EnsEMBL::Variation::DBSQL::BaseAdaptor;
use Data::Dumper;
our @ISA = ('Bio::EnsEMBL::Variation::DBSQL::BaseAdaptor');

use base qw(Exporter);
our @EXPORT_OK = qw($CONFIG_FILE);

our $CONFIG_FILE;


=head2 new

  Arg [-CONFIG]: string - path to JSON configuration file
  Example    : my $vca = Bio::EnsEMBL::Variation::VCFCollectionAdaptor->new(
                 -config => '/path/to/vcf_config.json'
               );

  Description: Constructor.  Instantiates a new VCFCollectionAdaptor object.
  Returntype : Bio::EnsEMBL::Variation::DBSQL::VCFCollectionAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  my $self;
  eval {$self = $class->SUPER::new(shift);};

  my $config = $self->config;

  unless($config && scalar keys %$config) {
    my ($config_file) = rearrange([qw(CONFIG_FILE)], @_);
    $config_file = $self->config_file($config_file); 
    
    throw("ERROR: No config file defined") unless defined($config_file);
    throw("ERROR: Config file $config_file does not exist") unless -e $config_file;
    
    # read config from JSON config file
    open IN, $config_file or throw("ERROR: Could not read from config file $config_file");
    local $/ = undef;
    my $json_string = <IN>;
    close IN;
    
    # parse JSON into hashref $config
    $config = JSON->new->decode($json_string) or throw("ERROR: Failed to parse config file $config_file");
  }
  
  $self->config($config);
  throw("ERROR: No collections defined in config file") unless $config->{collections} && scalar @{$config->{collections}};

  $self->root_dir();

  $self->tmpdir();
  
  bless($self, $class);

  return $self;

}

sub config_file {
  my ($self, $config_file) = @_;
  if (!$config_file) {
    if (!$self->{config_file}) {
      # try and get config file from global variable or ENV
      $config_file ||= $CONFIG_FILE || ($self->db ? $self->db->vcf_config_file : undef) || $ENV{ENSEMBL_VARIATION_VCF_CONFIG_FILE};
      # try and find default config file in API dir
      if(!defined($config_file)) {
        my $mod_path  = 'Bio/EnsEMBL/Variation/DBSQL/VCFCollectionAdaptor.pm';
        $config_file  = $INC{$mod_path};
        $config_file =~ s/VCFCollectionAdaptor\.pm/vcf_config\.json/ if $config_file;
      }
      $self->{config_file} = $config_file;
    } else {
      $self->{config_file} = $config_file;
    }
  }
  return $self->{config_file};
}


sub config {
  my ($self, $config) = @_;
  if ($config) {
    $self->{config} = $config;
    $self->db->vcf_config($config) if $self->db;
  } else {
    if (!$self->{config}) {
      # Try to get it from DBAdaptor
      $self->{config} = $self->db->vcf_config if $self->db;
    }  
  } 
  return $self->{config};
}

sub root_dir {
  my ($self, $root_dir) = @_;
  if (!$root_dir) {
    if (!$self->{root_dir}) {
      my $root_dir = '';
      if($ENV{ENSEMBL_VARIATION_VCF_ROOT_DIR}) {
        $root_dir = $ENV{ENSEMBL_VARIATION_VCF_ROOT_DIR}.'/';
      }
      elsif($self->db && $self->db->vcf_root_dir) {
        $root_dir = $self->db->vcf_root_dir.'/';
      }
      $self->{root_dir} = $root_dir;
    }
  } else {
    $self->{root_dir} = $root_dir;  
  }
  return $self->{root_dir};
}

sub tmpdir {
  my ($self, $tmpdir) = @_;
  if (!$tmpdir) {
    if (!$self->{tmpdir}) {
      my $tmpdir = cwd();
      if($ENV{ENSEMBL_VARIATION_VCF_TMP_DIR}) {
        $tmpdir = $ENV{ENSEMBL_VARIATION_VCF_TMP_DIR}.'/';
      }
      elsif($self->db && $self->db->vcf_tmp_dir) {
        $tmpdir = $self->db->vcf_tmp_dir.'/';
      }
      $self->{tmpdir} = $tmpdir;
    }
  } else {
    $self->{tmpdir} = $tmpdir;  
  }
  return $self->{tmpdir};
}

# Internal method checking if a remote VCF file exists
sub _ftp_file_exists {
  my $self = shift;
  my $uri = URI->new(shift);

  my $ftp = Net::FTP->new($uri->host) or die "Connection error($uri): $@";
  $ftp->login('anonymous', 'guest') or die "Login error", $ftp->message;
  my $exists = defined $ftp->size($uri->path);
  $ftp->quit;

  return $exists;
}


1;
