# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Familiars.pm
#   Class for familiar information

package KoL::Familiars;

use strict;
use KoL;
use KoL::Logging;
use KoL::Session;
use KoL::Item;
use KoL::Familiar;

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
        'kol'       => $kol,
        'session'   => $args{'session'},
        'log'       => KoL::Logging->new(),
        'current'   => undef,
        'familiars' => {},
        'equipment' => {},
        'dirty'     => 0
    };
    
    bless($self, $class);
    
    return($self);
}

sub dirty {
    my $self = shift;
    
    $self->{'log'}->debug("Checking dirtiness against " . $self->{'dirty'});
    return($self->{'kol'}->dirty() > $self->{'dirty'});
}

sub update {
    my $self = shift;
    my $resp = ref($_[0]) ne 'HTTP::Response' ? undef : shift;
    my $log = $self->{'log'};
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(1) if (!$self->dirty() && !$resp);
    
    $log->debug("Updating familiar info.");
    
    # Reset items in use by familiars.
    foreach my $id (keys(%{$self->{'familiars'}})) {
        $self->{'familiars'}{$id}->setCurrent(0);
        my $eq = $self->{'familiars'}{$id}->equip();
        next if (!$eq);
        $eq->setCount(0);
        $eq->setLocked(0);
        $eq->setInUse(0);
    }
    
    # Reset unused items.
    foreach my $name (keys(%{$self->{'equipment'}})) {
        my $eq = $self->{'equipment'}{$name};
        $eq->setCount(0);
        $eq->setLocked(0);
        $eq->setInUse(0);
    }
    
    # Unset the current familiar in case they don't have a current familiar
    #   anymore.
    $self->{'current'} = undef;
    
    $log->msg("Processing familiar.php.", 15);
    $resp = $self->{'session'}->get('familiar.php') if (!$resp);
    return (0) if (!$resp);
        
    my $content = $resp->content();
    
    # Current familiar
    if ($content =~ m/Current Familiar:.+?fam\((.+?)\).*?<b>(.+?)<.+?br>(\d+)-\S+ (.+?) \(([\d,]+).+?, ([\d,]+) /s) {
        my ($current);
        my $id = $1;
        my $name = $2;
        my $weight = $3;
        my $type = $4;
        my $exp = $5;
        my $kills = $6;
        
        $log->debug("Processing current familiar.");
        if (exists($self->{'familiars'}{$id})) {
            $current = $self->{'familiars'}{$id};
        } else {
            $current = KoL::Familiar->new(
                'id'            => $id,
                'name'          => $name,
                'type'          => $type,
                'controller'    => $self,
            );
            return (0) if (!$current);
            $self->{'familiars'}{$id} = $current;
        }
        $self->{'current'} = $current;
        
        # Update info.
        $current->setWeight($weight);
        $current->setExp($exp);
        $current->setKills($kills);
        $current->setCurrent(1);
        
        if ($content !~ m/>Equipment:.+?descitem\((\d+)\)/s) {
            # Current familiar might have been un-equipped.
            $current->setEquip(undef);
        } else {
            my ($equip);
            my $descid = $1;
            $log->debug("Processing current familiar's equipment ($descid).");
            if ($current->equip() && $current->equip()->descid() == $descid) {
                $equip = $current->equip();
            } else {
                $equip = KoL::Item->new(
                    'descid'        => $descid,
                    'controller'    => $self,
                );
                return(0) if (!$equip);
                $current->setEquip($equip);
            }
            
            $equip->setInUse($equip->inUse() + 1);
            $equip->setCount($equip->count() + 1);
            $equip->setLocked($content =~ m%itemimages/padlock.gif% ? 1 : 0);
            
            $current->equip($equip);
        }
    }
    
    # Extra equipment
    if ($content =~ m/<select name=whichitem>(.+?)<\/select>/s) {
        $log->debug("Processing extra equipment.");
        my $opts = $1;
        while ($opts =~ m/value=(\d+)>(.+?)</gs) {
            my $eid = $1;
            my $name = $2;
            my $count = 1;
            
            next if ($name =~ m/select an item/);
            $log->debug("Working with '$name' and '$eid'.");
            
            if ($name =~ m/^(.+?) \(([\d,]+)\)/s) {
                $name = $1;
                $count = $2;
                $count =~ s/,//g
            }
            
            my ($equip);
            if (exists($self->{'equipment'}{$name})) {
                $equip = $self->{'equipment'}{$name};
            } else {
                $equip = KoL::Item->new(
                    'name'          => $name,
                    'controller'    => $self,
                );
                return(0) if (!$equip);
                $self->{'equipment'}{$name} = $equip;
            }
            
            $equip->setFeid($eid);
            $equip->setCount($equip->count() + $count);
            
            $self->{'equipment'}{$equip->name()} = $equip;
        }
    }
    
    # Familiars
    while ($content =~ m/<input .+? value=(\d+)>.*?<b>(.+?)<.+?(\d+)-\S+ (.+?) \(([\d,]+).+?([\d,]+)(.+?)<\/tr>/gs) {
        my ($fam);
        my $id = $1;
        my $name = $2;
        my $weight = $3;
        my $type = $4;
        my $exp = $5;
        my $kills = $6;
        my $equip = $7;
        
        $log->debug("Processing '$name' ($id).");
        if (exists($self->{'familiars'}{$id})) {
            $fam = $self->{'familiars'}{$id};
        } else {
            $fam = KoL::Familiar->new(
                'id'            => $id,
                'name'          => $name,
                'type'          => $type,
                'controller'    => $self,
            );
            return(0) if (!$fam);
            $self->{'familiars'}{$id} = $fam;
        }
        
        # Update info.
        $fam->setWeight($weight);
        $fam->setExp($exp);
        $fam->setKills($kills);
        $fam->setCurrent(0);
        
        if ($equip !~ m/descitem\((.+?)\)/s) {
            # It may have been unequipped.
            $fam->setEquip(undef);
        } else {
            my ($equip);
            my $descid = $1;
            $log->debug("Processing familiar's equipment ($descid).");
            if ($fam->equip() && $fam->equip()->descid() == $descid) {
                $equip = $fam->equip();
            } else {
                $equip = KoL::Item->new(
                    'descid'        => $descid,
                    'controller'    => $self,
                );
                return(0) if (!$equip);
                $fam->setEquip($equip);
            }
            
            $equip->setInUse($equip->inUse() + 1);
            $equip->setCount($equip->count() + 1);
        }
    }
    
    # Mark the update time so we know when we need to update again.
    $self->{'dirty'} = $self->{'kol'}->time();
    
    return(1);
}

sub availableEquipment {
    my $self = shift;
    
    $self->{'log'}->debug("Getting available equipment.");
    return(undef) if ($self->dirty() && !$self->update());
    
    my (@equip);
    foreach my $name (keys(%{$self->{'equipment'}})) {
        push(@equip, $self->{'equipment'}{$name});
    }
    
    return(\@equip);
}

sub currentFamiliar {
    my $self = shift;
    
    $@ = "";
    $self->{'log'}->debug("Getting current familiar.");
    return(undef) if ($self->dirty() && !$self->update());
    
    return($self->{'current'});
}

sub allFamiliars {
    my $self = shift;
    
    $@ = "";
    $self->{'log'}->debug("Getting all familiars.");
    return(undef) if ($self->dirty() && !$self->update());
    
    my (@fams);
    foreach my $id (keys(%{$self->{'familiars'}})) {
        push(@fams, $self->{'familiars'}{$id});
    }
    return(\@fams);
}

sub changeName {
    my $self = shift;
    my $fam = shift;
    my $name = shift;
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    if (ref($fam) ne 'KoL::Familiar') {
        $@ = "Invalid Familiar reference.";
        return(0);
    }
    
    $self->{'log'}->debug("Changing name of " . $fam->name());
    
    if ($name =~ m/^\s*$/) {
        $@ = "Whitespace is not a valid name!";
        return(0);
    }
    
    # If it's current, it doesn't seem to use it's real id.
    my $fid = $fam->id();
    $fid = 0 if ($self->{'current'}->id() == $fid);
    
    my $resp = $self->{'session'}->post('familiarnames.php', {
        'action'    => 'Doodit',
        "fam$fid"   => $name,
        'pwd'       => $self->{'session'}->pwdhash(),
    });
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked by we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
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

sub unequip {
    my $self = shift;
    my $fam = shift;
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    if (ref($fam) ne 'KoL::Familiar') {
        $@ = "Invalid Familiar reference.";
        return(0);
    }
    
    return(0) if ($self->dirty() && !$self->update());
    
    $self->{'log'}->debug("Unequiping " . $fam->name());
    
    my $page = 'familiar.php';
    my $form = {
        'pwd'       => $self->{'session'}->pwdhash(),
        'action'    => 'unequip',
    };
    
    my $fid = $fam->id();
    if ($self->{'current'}->id() != $fid) {
        $form->{'famid'} = $fid;
    } else {
        $page = 'inv_equip.php';
        $form->{'type'} = 'familiarequip';
        $form->{'terrarium'} = 1;
    }
    my $resp = $self->{'session'}->get($page, $form);
    
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked by we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
    if ($resp->content() =~ m/You either don't have a familiar of that type/ ||
        $resp->content() =~ m/You don't seem to have anything in that slot/) {
        $self->{'log'}->debug("No familiar or no equipment on it.");
        return(1);
    }
    
    if ($resp->content() !~ m/Item unequipped/) {
        $self->{'session'}->logResponse("Unable to unequip item", $resp);
        $@ = "Unable to unequip item";
        return(0);
    }
    
    return(1);
}

sub equip {
    my $self = shift;
    my $fam = shift;
    my $item = shift;
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(0) if ($self->dirty() && !$self->update());
    
    if (ref($fam) ne 'KoL::Familiar') {
        $@ = "Invalid Familiar reference.";
        return(0);
    }
    
    $self->{'log'}->debug("Equiping " . $fam->name() . " with " .
                            $item->name());
    
    if (ref($item) ne 'KoL::Item::FamiliarEquipment') {
        $@ = "Item is not familiar equipment.";
        return(0);
    }
    if (!$item->feid()) {
        $@ = "None of these items are available for equipping.";
        use Data::Dumper;
        print Dumper($item);
        return(0);
    }
    
    # If it's current, it doesn't seem to use it's real id.
    my $fid = $fam->id();
    $fid = -1 if ($self->{'current'}->id() == $fid);
    
    my $resp = $self->{'session'}->post('familiar.php', {
        'action'    => 'equip',
        'whichfam'  => $fid,
        'whichitem' => $item->feid(),
        'pwd'       => $self->{'session'}->pwdhash(),
    });
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked by we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
    if ($resp->content() =~ m/Only a specific familiar type/) {
        $@ = "Equipment invalid for this familiar.";
        return(0);
    }
    
    if ($resp->content() !~ m/equips an item/) {
        $self->{'session'}->logResponse("Unable to equip item", $resp);
        $@ = "Unable to equip item!";
        return(0);
    }
    
    return(1);
}

sub unlock {
    my $self = shift;
    
    $self->{'log'}->debug("Unlock");
    return($self->lock(1, @_));
}

sub lock {
    my $self = shift;
    my $unlock = shift || 0;
    
    $self->{'log'}->debug("(Un)Locking");
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(0) if ($self->dirty() && !$self->update());
    
    # Can't lock what's not there
    if (!$self->{'current'} || !$self->{'current'}->equip()) {
        $@ = "No current familiar or it is not equiped.";
        return(0);
    }
    
    my $equip = $self->{'current'}->equip();
    if ($unlock && !$equip->locked()) {
        $@ = "The current equipment is not locked.";
        return(1); # We set the message in case they want some info, but we'll "succeed".
    }

    if (!$unlock && $equip->locked()) {
        $@ = "The current equipment is already locked.";
        return(1); # We set the message in case they want some info, but we'll "succeed".
    }
    
    my $resp = $self->{'session'}->get('familiar.php', {
        'action'    => 'lockequip',
        'pwd'       => $self->{'session'}->pwdhash(),
    });
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked by we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
    if ($resp->content() =~ m/equipped by one kind of familiar\. Strange, but true/) {
        $@ = "You can not lock familiar specific equipment.";
        return(0);
    }
    
    if ($resp->content() !~ m/Familiar equipment [(un)]*locked/) {
        $self->{'session'}->logResponse("Unable to (un)lock equipment:", $resp);
        $@ = "Unable to (un)lock equipment!";
        return(0);
    }
    
    # Rebuild the familiar info based off the result.
    return($self->update($resp));
}

1;
