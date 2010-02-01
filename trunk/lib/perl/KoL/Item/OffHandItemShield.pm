# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# OffHandItemShield.pm
#   Class representation of an off-hand (shield) item.

package KoL::Item::OffHandItemShield;

use strict;
use base qw(KoL::Item::OffHandItem);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::OffHandItem->new(%args);
    return(undef) if (!$self);
    
    my $content = $args{'content'};
    
    bless($self, $class);
    
    return($self);
}

1;
