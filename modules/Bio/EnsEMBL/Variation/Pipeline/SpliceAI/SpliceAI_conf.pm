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
package Bio::EnsEMBL::Variation::Pipeline::SpliceAI::SpliceAI_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
 # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
    my ($self) = @_;

    # The hash returned from this function is used to configure the
    # pipeline, you can supply any of these options on the command
    # line to override these default values.
    
    # You shouldn't need to edit anything in this file other than
    # these values, if you find you do need to then we should probably
    # make it an option here, contact the variation team to discuss
    # this - patches are welcome!

    return {
        %{ $self->SUPER::default_options()
        },    # inherit other stuff from the base class

        hive_auto_rebalance_semaphores => 1,
        hive_default_max_retry_count => 0,
        hive_force_init      => 1,
        hive_use_param_stack => 1,

        pipeline_name         => $self->o('pipeline_name'),
        main_dir              => $self->o('main_dir'), # main_dir = '/gpfs/nobackup/ensembl/dlemos/spliceai/Ensembl_input_files/all_snps_files_from_main_file_gene/'
        input_dir             => $self->o('input_dir'), # input_dir = '/gpfs/nobackup/ensembl/dlemos/spliceai/Ensembl_input_files/all_snps_files_from_main_file_gene/TMP'
        output_dir            => $self->o('output_dir'), # output_dir = '/gpfs/nobackup/ensembl/dlemos/spliceai/Ensembl_output_files/PIPELINE_TMP'
        fasta_file            => $self->o('fasta_file'), # '/hps/nobackup2/production/ensembl/dlemos/files/Homo_sapiens.GRCh38.dna.toplevel.fa'
        gene_annotation       => $self->o('gene_annotation'), # '/homes/dlemos/work/tools/SpliceAI_files_output/gene_annotation/ensembl_gene/grch38_MANE_8_7.txt'
        step_size             => 50,
        output_file_name      => 'spliceai_scores_chr_',

        pipeline_wide_analysis_capacity => 25,        

        pipeline_db => {
            -host   => $self->o('hive_db_host'),
            -port   => $self->o('hive_db_port'),
            -user   => $self->o('hive_db_user'),
            -pass   => $self->o('hive_db_password'),            
            -dbname => $ENV{'USER'} . '_' . $self->o('pipeline_name'),
            -driver => 'mysql',
        },
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},
        'default' => { 'LSF' => '-n 16 -q production-rh74 -R"select[mem>4000] rusage[mem=4000]" -M4000'},
        'medium'  => { 'LSF' => '-n 16 -q production-rh74 -R"select[mem>6000] rusage[mem=6000]" -M6000'},
        'high'    => { 'LSF' => '-n 16 -q production-rh74 -R"select[mem>8500] rusage[mem=8500]" -M8500'},
    };
}

sub pipeline_analyses {
  my ($self) = @_;
  my @analyses;
  push @analyses, (
      # pre run checks, directories exist etc
      {   -logic_name => 'init_files',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
          -input_ids  => [{}],
          -parameters => {
            'input_dir' => $self->o('input_dir'),
            'inputcmd'  => 'find #input_dir# -type f -name "all_snps_ensembl_38_*.vcf" -printf "%f\n"',
          },
          -flow_into  => {
            '2->A' => {'split_files' => {'input_file' => '#_0#'}},
            'A->1' => ['init_spliceai'],
          },
      },
      { -logic_name => 'split_files',
        -module => 'Bio::EnsEMBL::Variation::Pipeline::SpliceAI::SplitFiles',
        -parameters => {
          'main_dir'              => $self->o('main_dir'),
          'input_dir'             => $self->o('input_dir'),
          'output_dir'            => $self->o('output_dir'),
          'step_size'             => $self->o('step_size'),
        },
      },
      {   -logic_name => 'init_spliceai',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
          -input_ids  => [{}],
          -parameters => {
            'input_dir' => $self->o('main_dir') . "/splited_files_input", # TODO directory should be the output from 'split_files': $self->o('main_dir') . "/splited_files_input/chrx"
            # 'input_dir' => $self->o('new_input_dir'),
            'inputcmd'  => 'ls #input_dir#',
          },
          -flow_into  => {
            '2->A' => {'run_spliceai' => {'new_input_dir' => '#_0#'}},
            # '2->A' => {'run_spliceai' => INPUT_PLUS()},
            'A->1' => ['finish_files'],
          },
      },
      { -logic_name => 'run_spliceai',
        -module => 'Bio::EnsEMBL::Variation::Pipeline::SpliceAI::RunSpliceAI',
        -parameters => {
          'main_dir'              => $self->o('main_dir'),
          'output_dir'            => $self->o('output_dir'),
          'fasta_file'            => $self->o('fasta_file'),
          'gene_annotation'       => $self->o('gene_annotation'),
          'output_file_name'      => $self->o('output_file_name'),
        },
      },
      { -logic_name => 'finish_files',
        -module => 'Bio::EnsEMBL::Variation::Pipeline::SpliceAI::FinishRunSpliceAI',
        -parameters => {
          'input_dir'             => $self->o('input_dir'),
          'output_file_name'      => $self->o('output_file_name'),
        },
      }
  );
  return \@analyses;
}
1;
