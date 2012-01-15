# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Food.pm
#   Class representation of a food item.

package KoL::Item::Beverage;

use strict;
use base qw(KoL::Item::Food);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Food->new(%args);
    return(undef) if (!$self);
    
    bless($self, $class);
    return($self);
}

1;
