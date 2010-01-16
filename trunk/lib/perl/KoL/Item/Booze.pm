# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Booze.pm
#   Class representation of a booze item.

package KoL::Item::Booze;

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
