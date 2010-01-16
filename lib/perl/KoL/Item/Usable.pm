# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Usable.pm
#   Class representation of a usable item.

package KoL::Item::Usable;

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
