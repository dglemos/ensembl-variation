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
package Bio::EnsEMBL::Variation::Pipeline::SpliceAI::SplitFiles;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Variation::Pipeline::SpliceAI::BaseSplitFiles');

use FileHandle;
use Bio::EnsEMBL::IO::Parser::BedTabix;
use Bio::EnsEMBL::IO::Parser::VCF4Tabix;

sub run {
  my $self = shift;
  $self->set_chr_from_filename();
  $self->split_input_file();
}

sub set_chr_from_filename {
  my $self = shift;
  my $input_file = $self->param_required('input_file');
  #all_snps_ensembl_38_13.vcf
  $input_file =~ /.*_(.*)\.vcf$/;
  my $chr = $1; 
  if (!$chr) {
    die("Could not get chromosome name from file name ($input_file).");
  }
  $self->param('chr', $chr);
}

sub split_input_file {
  my $self = shift;
  my $vcf_file = $self->param_required('input_file');
  my $main_dir = $self->param_required('main_dir');
  my $input_dir = $self->param_required('input_dir');
  my $step_size = $self->param_required('step_size');

  if (! -d $input_dir) {
    die("Directory ($input_dir) doesn't exist");
  }

  my $chr = $self->param('chr');

  if (! -e "$input_dir/$vcf_file") {
    die("File ($input_dir/$vcf_file) doesn't exist.");
  }

  my $new_dir = $main_dir."/splited_files/chr$chr";
  my $new_file = $new_dir."/all_snps_ensembl_38_chr".$chr.".";

  $self->create_dir($new_dir);
  $self->run_system_command("split -l $step_size --additional-suffix=.vcf $input_dir/$vcf_file $new_file");

  # Files splited by number of lines (from input) and with header that are going to be used as input for SpliceAI run
  my $new_input_dir = $main_dir."/splited_files_input/chr$chr";

  $self->create_dir($new_input_dir);

  opendir(my $read_dir, $new_dir) or die $!;

  while(my $splited_vcf = readdir($read_dir)) {
    next if ($splited_vcf =~ m/^\./);

    open(my $write, '>', $new_input_dir . '/' . $splited_vcf) or die $!; 
    print $write "##fileformat=VCFv4.2\n##fileDate=20200313\n##reference=GRCh38/hg38\n##contig=<ID=1,length=248956422>\n##contig=<ID=2,length=242193529>\n##contig=<ID=3,length=198295559>\n##contig=<ID=4,length=190214555>\n##contig=<ID=5,length=181538259>\n##contig=<ID=6,length=170805979>\n##contig=<ID=7,length=159345973>\n##contig=<ID=8,length=145138636>\n##contig=<ID=9,length=138394717>\n##contig=<ID=10,length=133797422>\n##contig=<ID=11,length=135086622>\n##contig=<ID=12,length=133275309>\n##contig=<ID=13,length=114364328>\n##contig=<ID=14,length=107043718>\n##contig=<ID=15,length=101991189>\n##contig=<ID=16,length=90338345>\n##contig=<ID=17,length=83257441>\n##contig=<ID=18,length=80373285>\n##contig=<ID=19,length=58617616>\n##contig=<ID=20,length=64444167>\n##contig=<ID=21,length=46709983>\n##contig=<ID=22,length=50818468>\n##contig=<ID=X,length=156040895>\n##contig=<ID=Y,length=57227415>\n##contig=<ID=MT,length=16569>\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\n";

    open(my $fh, '<:encoding(UTF-8)', $new_dir . '/' . $splited_vcf)
      or die "Could not open file '$new_dir/$splited_vcf' $!";

    while (my $row = <$fh>) {
      chomp $row;
      next if($row =~ /^#/);

      my @columns = split /\t/, $row;

      my @alt_splited = split /,/, $columns[4];
      foreach my $x (@alt_splited) {
        print $write $columns[0] . "\t" . $columns[1] . "\t" . $columns[2] . "\t" . $columns[3] . "\t" . $x . "\t.\t.\t.\n";
      }
    }
    close($write);
    close($fh);
  }
  close($read_dir);

  $self->run_system_command("rm -rf $main_dir/splited_files/chr$chr");

  $self->param('new_input_dir', $new_input_dir);
}

1;
