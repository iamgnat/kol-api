# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Food.pm
#   Class representation of a food item.

package KoL::Item::Food;

use strict;
use base qw(KoL::Item::Misc);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Misc->new(%args);
    return(undef) if (!$self);
    
    bless($self, $class);
    
    return($self);
}

1;
