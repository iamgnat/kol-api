# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Weapon.pm
#   Class representation of a weapon item.

package KoL::Item::Weapon;

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

1;
