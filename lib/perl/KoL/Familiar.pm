# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Familiar.pm
#   Class representation of an individual familiar.

package KoL::Familiar;

use strict;

sub new {
    my $class = shift;
    my %args = @_;
    
    foreach my $key (qw(id type controller)) {
        next if (exists($args{$key}));
        $@ = "'$key' not suplied in the argument hash!";
        return(undef);
    }
    
    my $content = $args{'content'};
    my $self = {
        'id'                    => $args{'id'},
        'name'                  => undef,
        'type'                  => $args{'type'},
        'controller'            => $args{'controller'},
        'weight'                => 0,
        'exp'                   => 0,
        'kills'                 => 0,
        'current'               => 0,
        'equip'                 => undef,
    };
    
    bless($self, $class);
    
    $self->setName($args{'name'}) if (exists($args{'name'}));
    $self->setWeight($args{'weight'}) if (exists($args{'weight'}));
    $self->setExp($args{'exp'}) if (exists($args{'exp'}));
    $self->setKills($args{'kills'}) if (exists($args{'kills'}));
    $self->setCurrent($args{'current'}) if (exists($args{'current'}));
    $self->setEquip($args{'equip'}) if (exists($args{'equip'}));
    
    return($self);
}

sub getInfo {
    my $self = shift;
    my $key = shift;
    $@ = "";
    
    # Don't try to update the controller if the update is already
    #   in progress.
    my $update = ref($self->{'controller'}) . '::update';
    my $found = 0;
    for (my $i = 1 ; my @caller = caller($i) ; $i++) {
        if ($caller[3] eq $update) {
            $found = 1;
            last;
        }
    }
    if (!$found) {
        return(undef) if(!$self->{'controller'}->update());
    }
    
    return($self->{$key});
}

sub id {return($_[0]->{'id'});}
sub type {return($_[0]->{'type'});}
sub name {return($_[0]->getInfo('name'));}
sub weight {return($_[0]->getInfo('weight'));}
sub exp {return($_[0]->getInfo('exp'));}
sub kills {return($_[0]->getInfo('kills'));}
sub equip {return($_[0]->getInfo('equip'));}
sub isCurrent {return($_[0]->getInfo('current'));}
sub unequip {return($_[0]->{'controller'}->unequip(@_));}
sub changeName {return($_[0]->{'controller'}->changeName(@_));}
sub take {return($_[0]->{'controller'}->takeThisOne(@_));}

sub setName {
    my $self = shift;
    my $val = shift;
    
    $self->{'name'} = $val;
    return;
}

sub setWeight {
    my $self = shift;
    my $val = shift;
    
    return if ($val !~ m/^[\d,]+$/);
    
    $val =~ s/,//g;
    $self->{'weight'} = $val;
    return;
}

sub setExp {
    my $self = shift;
    my $val = shift;
    
    return if ($val !~ m/^[\d,]+$/);
    
    $val =~ s/,//g;
    $self->{'exp'} = $val;
    return;
}

sub setKills {
    my $self = shift;
    my $val = shift;
    
    return if ($val !~ m/^[\d,]+$/);
    
    $val =~ s/,//g;
    $self->{'kills'} = $val;
    return;
}

sub setCurrent {
    my $self = shift;
    my $val = shift;
    
    return if ($val !~ m/^[01]$/);
    
    $self->{'current'} = $val;
    return;
}

sub setEquip {
    my $self = shift;
    my $val = shift;
    
    return if (ref($val) ne 'KoL::Item::FamiliarEquipment');
    
    my $inuse = $val->inUse();
    $val->setInUse($inuse + 1);
    
    $self->{'equip'} = $val;
    return;
}

1;

