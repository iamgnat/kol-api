# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Pants.pm
#   Class representation of a pants item.

package KoL::Item::Pants;

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

# Stub out the bits that don't apply to pants.
sub subtype {}

1;
