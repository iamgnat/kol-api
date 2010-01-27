# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Familiar.pm
#   Class representation of a familiar hatchling item.

package KoL::Item::Familiar;

use strict;
use base qw(KoL::Item::Usable);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Misc->new(%args);
    return(undef) if (!$self);
    
    bless($self, $class);
    
    return($self);
}

1;
