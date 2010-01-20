# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# FamiliarEquipment.pm
#   Class representation of a familiar item.

package KoL::Item::FamiliarEquipment;

use strict;
use base qw(KoL::Item::Equipment);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Equipment->new(%args);
    return(undef) if (!$self);
    
    my $content = $args{'content'};
    
    $self->{'feid'} = $args{'feid'};
    
    bless($self, $class);
    
    return($self);
}

sub setLocked {$_[0]->{'locked'} = $_[1] ? 1 : 0;}
sub locked {return($_[0]->getInfo('locked'));}
sub feid {return($_[0]->{'feid'});}

# Stub out the bits that don't apply to familiar equipment.
sub subtype {}
sub power {}
sub muscleRequired {}
sub mysticalityRequired {}
sub moxieRequired {}
sub levelRequired {}

1;
