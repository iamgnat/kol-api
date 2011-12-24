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
    
    $self->{'quality'} = $args{'quality'} if (exists($args{'quality'}));
    
    bless($self, $class);
    
    return($self);
}

sub quality {return($_[0]->{'quality'});}

1;
