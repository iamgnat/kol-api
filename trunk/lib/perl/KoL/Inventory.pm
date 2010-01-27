# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Inventory.pm
#   Class for working with the inventory.

package KoL::Inventory;

use strict;
use KoL;
use KoL::Logging;
use KoL::Session;
use KoL::Item;

my (%_detailsCache);

sub new {
    my $class = shift;
    my %args = @_;
    my $kol = KoL->new();
    
    # Defaults.
    
    if (!exists($args{'session'})) {
        $@ = "You must supply a session object.";
        return(undef);
    }
    
    my $self = {
        'kol'           => $kol,
        'session'       => $args{'session'},
        'log'           => KoL::Logging->new(),
        'dirty'         => 0,
        'consumables'   => {},
        'equipment'     => {},
        'misc'          => {},
        'types'         => {},
    };
    
    bless($self, $class);
    
    return($self);
}

sub dirty {
    my $self = shift;
    
    return($self->{'kol'}->dirty() > $self->{'dirty'});
}

sub update {
    my $self = shift;
    my $log = $self->{'log'};
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(1) if (!$self->dirty());
    
    $log->debug("Updating inventory info.");
    
    # Reset items.
    my @groups = qw(consumables equipment misc);
    foreach my $group (@groups) {
        foreach my $name (keys(%{$self->{$group}})) {
            $self->{$group}{$name}->setCount(0);
            $self->{$group}{$name}->setInUse(0)
                if ($self->{$group}{$name}->can('setInUse'));
        }
    }
    
    
    for (my $i = 0 ; $i < @groups ; ) {
        my $group = $groups[$i];
        $i++;
        
        $log->debug("Processing inventory.php?which=$i for $group.");
        my $resp = $self->{'session'}->get('inventory.php', {'which' => $i});
        return (0) if (!$resp);
        
        my $content = $resp->content();
        while ($content =~ m/<img .+?'descitem\((.+?),.+?\).+?<b class="ircm">(.+?)<.+?<span(.+?)><font size=1>/sg) {
            my $descid = $1;
            my $name = $2;
            my $span = $3;
            my $count = 1;
            
            if ($span =~ m/\((.+?)\)/s) {
                $count = $1;
                $count =~ s/,//g;
            }
            
            $self->{'log'}->debug("Adding $count '$name' to inventory.");
            if (exists($self->{$group}{$name})) {
                $self->{$group}{$name}->setCount($count);
            } else {
                my $item = KoL::Item->new('controller' => $self, 'descid' => $descid);
                return(0) if (!$item);
                
                my $type = ref($item);
                $type =~ s/^KoL::Item:://;
                
                # Don't handle Familiar Equipment, make them use the
                #   Tererrarium for that.
                next if ($type eq 'FamiliarEquipment');
                
                $item->setCount($count);
                $self->{$group}{$item->name()} = $item;
                $self->{'types'}{$type}{$item->name()} = $item;
            }
        }
    }
    
    # Mark the update time so we know when we need to update again.
    $self->{'dirty'} = $self->{'kol'}->time();
    
    return(1);
}

sub getTypeOfItem {
    my $self = shift;
    my $type = shift;
    
    return(undef) if (!$self->update());
    return({}) if (!exists($self->{'types'}{$type}));
    
    my (%items);
    foreach my $name (keys(%{$self->{'types'}{$type}})) {
        next if ($self->{'types'}{$type}{$name}->count() == 0);
        $items{$name} = $self->{'types'}{$type}{$name};
    }
    
    if ($type eq 'Misc') {
        foreach my $name (keys(%{$self->{'types'}{'Usable'}})) {
            next if ($self->{'types'}{'Usable'}{$name}->count() == 0);
            $items{$name} = $self->{'types'}{'Usable'}{$name};
        }
        foreach my $name (keys(%{$self->{'types'}{'CraftingItem'}})) {
            next if ($self->{'types'}{'CraftingItem'}{$name}->count() == 0);
            $items{$name} = $self->{'types'}{'CraftingItem'}{$name};
        }
        foreach my $name (keys(%{$self->{'types'}{'Familiar'}})) {
            next if ($self->{'types'}{'Familiar'}{$name}->count() == 0);
            $items{$name} = $self->{'types'}{'Familiar'}{$name};
        }
    }
    
    return(\%items);
}

sub allItems {
    my $self = shift;
    
    return(undef) if (!$self->update());
    
    my (%items);
    foreach my $type (qw(consumables equipment misc)) {
        foreach my $name (keys(%{$self->{$type}})) {
            next if ($self->{$type}{$name}->count() == 0);
            $items{$name} = $self->{$type}{$name};
        }
    }
    
    return(\%items)
}

sub comsumables {
    my $self = shift;
    
    return(undef) if (!$self->update());
    
    my (%items);
    foreach my $name (keys(%{$self->{'consumables'}})) {
        next if ($self->{'consumables'}{$name}->count() == 0);
        $items{$name} = $self->{'consumables'}{$name};
    }
    
    return(\%items)
}

sub equipment {
    my $self = shift;
    
    return(undef) if (!$self->update());
    
    my %items = {};
    foreach my $name (keys(%{$self->{'equipment'}})) {
        next if ($self->{'equipment'}{$name}->count() == 0);
        $items{$name} = $self->{'equipment'}{$name};
    }
    
    return(\%items)
}

sub misc {
    my $self = shift;
    
    return(undef) if (!$self->update());
    
    my (%items);
    foreach my $name (keys(%{$self->{'misc'}})) {
        next if ($self->{'misc'}{$name}->count() == 0);
        $items{$name} = $self->{'misc'}{$name};
    }
    
    return(\%items)
}

sub accessories {return($_[0]->getTypeOfItem('Accessory'));}
sub booze {return($_[0]->getTypeOfItem('Booze'));}
sub combatItems {return($_[0]->getTypeOfItem('CombatItem'));}
sub food {return($_[0]->getTypeOfItem('Food'));}
sub hats {return($_[0]->getTypeOfItem('Hat'));}
sub miscellaneous {return($_[0]->getTypeOfItem('Misc'));}
sub offHandItems {return($_[0]->getTypeOfItem('OffHandItem'));}
sub pants {return($_[0]->getTypeOfItem('Pants'));}
sub potions {return($_[0]->getTypeOfItem('Potion'));}
sub shirts {return($_[0]->getTypeOfItem('Shirt'));}
sub weapons {return($_[0]->getTypeOfItem('Weapon'));}

1;
