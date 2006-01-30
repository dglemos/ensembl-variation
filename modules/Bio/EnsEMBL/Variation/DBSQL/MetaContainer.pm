#
# EnsEMBL module for Bio::EnsEMBL::Variation::DBSQL::MetaContainer
#
# Cared for by Daniel Rios
#
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

  Bio::EnsEMBL::Variation::DBSQL::MetaContainer - 
  Encapsulates all access to variation database meta information

=head1 SYNOPSIS

  my $meta_container = $db_adaptor->get_MetaContainer();

  my $default_population = $meta_container->get_default_LDPopulation();

=head1 DESCRIPTION

  An object that encapsulates specific access to variation db meta data

=head1 CONTACT

  Post questions to the EnsEMBL development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

package Bio::EnsEMBL::Variation::DBSQL::MetaContainer;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseMetaContainer;
use Bio::EnsEMBL::Utils::Exception qw(deprecate);


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseMetaContainer);


sub get_schema_version {
  my $self = shift;

  my $arrRef = $self->list_value_by_key( 'schema_version' );

  if( @$arrRef ) {
    my ($ver) = ($arrRef->[0] =~ /^\s*(\d+)\s*$/);
    if(!defined($ver)){ # old style format
      return 0;
    }
    return $ver;
  } else {
    warn("Please insert meta_key 'schema_version' " .
         "in meta table at core db.\n");
  }
  return 0;
}

1;
