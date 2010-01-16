# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Hat.pm
#   Class representation of a hat item.

package KoL::Item::Hat;

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

# Stub out the bits that don't apply to hats.
sub subtype {}

1;
