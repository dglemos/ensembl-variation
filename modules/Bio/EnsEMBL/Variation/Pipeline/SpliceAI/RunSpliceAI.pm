=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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
package Bio::EnsEMBL::Variation::Pipeline::SpliceAI::RunSpliceAI;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Variation::Pipeline::SpliceAI::BaseSplitFiles');

use FileHandle;
use Bio::EnsEMBL::IO::Parser::BedTabix;
use Bio::EnsEMBL::IO::Parser::VCF4Tabix;

sub run {
  my $self = shift;
  $self->set_chr_from_filename();
  $self->run_spliceai();
}

sub set_chr_from_filename {
  my $self = shift;
  my $input_file = $self->param_required('new_input_dir');
  $input_file =~ /chr(.*)/;
  my $chr = $1; 
  if (!$chr) {
    die("Could not get chromosome name from file name ($input_file).");
  }
  $self->param('chr', $chr);
}

sub run_spliceai {
  my $self = shift;
  my $main_dir = $self->param_required('main_dir');
  my $input_dir = $main_dir."/splited_files_input/".$self->param('new_input_dir'); # $main_dir/splited_files_input/chr$chr
  my $output_dir = $self->param_required('output_dir');
  my $fasta_file = $self->param_required('fasta_file');
  my $gene_annotation = $self->param_required('gene_annotation');

  if (! -d $input_dir) {
    die("Directory ($input_dir) doesn't exist");
  }

  my $chr = $self->param('chr');

  my $output_dir_chr = $output_dir."/chr".$chr;
  $self->create_dir($output_dir_chr);

  my $out_files_dir = $output_dir_chr."/out_files";
  my $output_vcf_files_dir = $output_dir_chr."/vcf_files";
  $self->create_dir($out_files_dir);
  $self->create_dir($output_vcf_files_dir);

  opendir(my $write, $input_dir) or die $!;

  while(my $vcf = readdir($write)) {
    next if ($vcf =~ m/^\./);

    my $err = $out_files_dir."/".$vcf.".err";
    my $out = $out_files_dir."/".$vcf.".out";

    my $cmd = "spliceai -I $input_dir/$vcf -O $output_vcf_files_dir/$vcf -R $fasta_file -A $gene_annotation";
    my ($exit_code, $stderr, $flat_cmd) = $self->run_system_command($cmd);
  }
  close($write);

}


1;
