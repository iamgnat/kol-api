# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# CombatItem.pm
#   Class representation of a combat item item.

package KoL::Item::CombatItem;

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
