# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# CraftingItem.pm
#   Class representation of a crafting item.

package KoL::Item::CraftingItem;

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
