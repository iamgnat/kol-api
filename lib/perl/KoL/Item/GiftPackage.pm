# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# GiftPackage.pm
#   Class representation of a gift package item.

package KoL::Item::GiftPackage;

use strict;
use base qw(KoL::Item::Usable);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Usable->new(%args);
    return(undef) if (!$self);
    
    my $content = $args{'content'};
    
    bless($self, $class);
    
    return($self);
}

1;
