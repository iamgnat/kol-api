# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# OffHandItem.pm
#   Class representation of an off-hand item.

package KoL::Item::OffHandItem;

use strict;
use base qw(KoL::Item::Equipment);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Equipment->new(%args);
    return(undef) if (!$self);
    
    my $content = $args{'content'};
    
    bless($self, $class);
    
    return($self);
}

# Stub out the bits that don't apply to off-hand items.
sub subtype {}

1;
