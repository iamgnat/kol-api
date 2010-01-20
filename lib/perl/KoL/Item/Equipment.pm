# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Equipment.pm
#   Generic class representation of an equipment item.

package KoL::Item::Equipment;

use strict;
use base qw(KoL::Item::Misc);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Misc->new(%args);
    return(undef) if (!$self);
    
    my $content = $args{'content'};
    
    # Power
    $self->{'power'} = $1 if ($content =~ m/>Power: <b>(\d+)</s);
    
    # Enchantments
    $self->{'enchantments'} = [];
    if ($content =~ m/>Enchantment:.+?<font.+?>(.+?)<\/font>/s) {
        my $encs = $1;
        while ($encs =~ m/(.+?)<br>/gs) {
            push(@{$self->{'enchantments'}}, $1);
        }
    }
    
    $self->{'inuse'} = exists($args{'inuse'}) ? $args{'inuse'} : 0;
    $self->{'subtype'} = exists($args{'subtype'}) ? $args{'subtype'} : undef;
    
    bless($self, $class);
    
    return($self);
}

sub subtype {return($_[0]->{'subtype'});}
sub power {return($_[0]->{'power'});}
sub enchantments {return($_[0]->{'enchantments'});}
sub inUse {return($_[0]->getInfo('inuse'))}

sub setInUse {
    my $self = shift;
    my $val = shift || 0;
    
    $self->{'inuse'} = $val;
    
    return;
}
1;
