# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Familiars.pm
#   Class for familiar information

package KoL::Familiars;

use strict;
use KoL;
use KoL::Logging;
use KoL::Session;
use KoL::Inventory;
use KoL::Wiki;

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
        'session'   => $args{'session'},
        'inventory' => $args{'inventory'} || undef,
        'log'       => KoL::Logging->new(),
        'current'   => undef,
        'familiars' => [],
        'equipment' => {},
    };
    
    bless($self, $class);
    
    return($self);
}

sub update {
    my $self = shift;
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    my ($resp);
    $self->{'log'}->msg("Updating familiar info.", 10);
    my $wiki = KoL::Wiki->new('session' => $self->{'session'});
    my $inv = KoL::Inventory->new('session' => $self->{'session'});
    
    my $equip = $self->{'inventory'} || KoL::Inventory->new('session' => $self->{'session'});
    
    my $familiars = [];
    my $equipment = {};
    my ($current);
    
    $self->{'log'}->msg("Processing familiar.php.", 15);
    $resp = $self->{'session'}->get('familiar.php');
    return (0) if (!$resp);
    
    my $content = $resp->content();
    
    # Current familiar
    if ($content =~ m/Current Familiar:.+?fam\((.+?)\).*?<b>(.+?)<.+?br>(\d+)-\S+ (.+?) \(([\d,]+).+?, ([\d,]+) /s) {
        $current = {
            'id'        => $1,
            'name'      => $2,
            'weight'    => $3,
            'type'      => $4,
            'exp'       => $5,
            'kills'     => $6,
            'equip'     => undef
        };
        $current->{'exp'} =~ s/,//g;
        $current->{'kills'} =~ s/,//g;
        
        if ($content =~ m/>Equipment:.+?descitem\((\d+)\)/s) {
            my $equip = $inv->itemInfo($1);
            if (!$equip) {
                $@ = "Unable to get current familiar equipment info: $@";
                return(0);
            }
            $equip->{'count'} = 1;
            $equip->{'usedby'} = [$current];
            $current->{'equip'} = $equip;
            $equipment->{$equip->{'name'}} = $equip;
        }
        
        push(@{$familiars}, $current);
    }
    
    # Extra equipment
    if ($content =~ m/<select name=whichitem>(.+?)<\/select>/s) {
        my $opts = $1;
        while ($opts =~ m/value=\d+>(.+?)</gs) {
            my $name = $1;
            my $count = 1;
            
            next if ($name =~ m/select an item/);
            
            if ($name =~ m/^(.+?) \(([\d,]+)\)/s) {
                $name = $1;
                $count = $2;
                $count =~ s/,//g
            }
            
            if (exists($equipment->{$name})) {
                $equipment->{$name}{'count'} += $count;
            } else {
                my $info = $wiki->getPage($name);
                if (!$info) {
                    $@ = "Unable to get wiki info for '$name': $@";
                    return(undef);
                }
                my $equip = $inv->itemInfo($info->{'desc'});
                if (!$equip) {
                    $@ = "Unable to get wiki item for '$name': $@";
                    return(undef);
                }
                $equip->{'count'} = $count;
                $equip->{'usedby'} = [];
                $equipment->{$name} = $equip;
            }
        }
    }
    
    # Familiars
    while ($content =~ m/<input .+? value=(\d+)>.*?<b>(.+?)<.+?(\d+)-\S+ (.+?) \(([\d,]+).+?([\d,]+)(.+?)<\/tr>/gs) {
        my $equip = $7;
        my $fam = {
            'id'        => $1,
            'name'      => $2,
            'weight'    => $3,
            'type'      => $4,
            'exp'       => $5,
            'kills'     => $6,
            'equip'     => undef
        };
        
        if ($equip !~ m/descitem\((.+?)\)/s) {
            undef($equip);
        } else {
            my $i = $1;
            $equip = $inv->itemInfo($i);
            if (!$equip) {
                $@ = "Unable to get familiar equipment info for '$i': $@";
                return(undef);
            }
            
            $fam->{'equip'} = $equip;
            if (exists($equipment->{$equip->{'name'}})) {
                $equipment->{$equip->{'name'}}{'count'}++;
                push(@{$equipment->{$equip->{'name'}}{'usedby'}}, $fam);
            }
        }
        
        push(@{$familiars}, $fam);
    }
    
    $self->{'current'} = $current;
    $self->{'familiars'} = $familiars;
    $self->{'equipment'} = $equipment;
    return(1);
}

sub changeName {
    my $self = shift;
    my $fid = shift;
    my $name = shift;
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    if ($fid !~ m/^\d+$/) {
        $@ = "'$fid' is an invalid Familiar ID.";
        return(0);
    }
    if ($name =~ m/^\s*$/) {
        $@ = "Whitespace is not a valid name!";
        return(0);
    }
    
    # If it's current, it doesn't seem to use it's real id.
    $fid = 0 if ($self->{'current'}{'id'} == $fid);
    
    my $resp = $self->{'session'}->post('familiarnames.php', {
        'action'    => 'Doodit',
        "fam$fid"   => $name,
        'pwd'       => $self->{'session'}{'pwdhash'},
    });
    return(0) if (!$resp);
    
    if ($resp->content() !~ m/Results:.*?<table><tr><td>(.+?)</s) {
        $self->{'session'}->logResponse("Unable to get results", $resp);
        $@ = "Unable to get results!";
        return(0);
    }
    my $result = $1;
    if ($result !~ m/All familiar names set successfully/) {
        $self->{'session'}->logResponse("Unable to change name: $result", $resp);
        $@ = "Unable to change name: $result";
        return(0);
    }
    
    return(1);
}

1;
