# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Outfits.pm
#   Class for working with outfits.

package KoL::Outfits;

use strict;
use KoL;
use KoL::Logging;
use KoL::Item;

sub new {
    my $class = shift;
    my %args = @_;
    my $kol = KoL->new();
    
    # Defaults.
    if (!exists($args{'session'}) && ref($args{'session'}) eq 'KoL::Session') {
        $@ = "You must supply a KoL::Session object.";
        return(undef);
    }
    
    my $self = {
        'kol'           => $kol,
        'session'       => $args{'session'},
        'log'           => KoL::Logging->new(),
        'dirty'         => 0,
        'outfits'       => {'normal' => {}, 'custom' => {}},
        'prev_id'       => undef,
    };
    
    bless($self, $class);
    
    return($self);
}

sub dirty {
    my $self = shift;
    
    return($self->{'session'}->dirty() > $self->{'dirty'});
}

sub update {
    my $self = shift;
    my $log = $self->{'log'};
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(1) if (!$self->dirty());
    
    $log->debug("Updating outfit info.");
    
    # Reset items.
    $self->{'outfits'}{'normal'} = {};
    $self->{'outfits'}{'custom'} = {};
    $self->{'prev_id'} = undef;
    
    # Gather the data.
    $log->debug("Processing inventory.php?which=2.");
    my $resp = $self->{'session'}->get('inventory.php', {'which' => 2});
    return (0) if (!$resp);
        
    my $content = $resp->content();
    if ($content !~ m/<select name=whichoutfit>(.+?)<\/select>/s) {
        $self->{'session'}->logResponse("Unable to find outfit select.", $resp);
        $@ = "Unable to find outfit select.";
        return(0);
    }
    my $opts = $1;
    
    if ($opts =~ m/<optgroup label='Normal Outfits'>(.+?)<\/optgroup>/s) {
        my $norm = $1;
        
        $log->debug("Processing normal outfits.");
        while ($norm =~ /<option value=(.+?)>(.+?)<\/option>/gs) {
            my $name = $2;
            my $id = $1;
            $id =~ s/["']//g;

            $self->{'outfits'}{'normal'}{$name} = $id;
        }
    }
    
    if ($opts =~ m/<optgroup label='Custom Outfits'>(.+?)<\/optgroup>/s) {
        my $norm = $1;
        
        $log->debug("Processing custom outfits.");
        while ($norm =~ /<option value=(.+?)>(.+?)<\/option>/gs) {
            my $name = $2;
            my $id = $1;
            $id =~ s/["']//g;

            $self->{'outfits'}{'custom'}{$name} = $id;
        }
    }
    
    if ($opts !~ m/<optgroup label="Automatic Outfits">(.+?)<\/optgroup>/s) {
        $self->{'session'}->logResponse("Unable to locate automatic outfits.", $resp);
        $@ = "Unable to locate automatic outfits.";
        return(0);
    }
    my $prev = $1;
    $log->debug("Getting Previous Outfit id.");
    if ($prev !~ /<option value=(.+?)>Your Previous Outfit<\/option>/s) {
        $self->{'session'}->logResponse("Unable to locate previous outfit id.", $resp);
        $@ = "Unable to locate previous outfit id.";
        return(0);
    }
    $self->{'prev_id'} = $1;
    $self->{'prev_id'} =~ s/["']//g;
    
    # Mark the update time so we know when we need to update again.
    $self->{'dirty'} = $self->{'session'}->time();
    
    return(1);
}

sub getOutfits {
    my $self = shift;
    my $type = shift;
    
    return(undef) if (!$self->update());
    return([]) if (!exists($self->{'outfits'}{$type}));
    
    my @outfits = sort(keys(%{$self->{'outfits'}{$type}}));
    return(\@outfits);
}

sub normal {return($_[0]->getOutfits('normal'));}
sub custom {return($_[0]->getOutfits('custom'));}

sub wear {
    my $self = shift;
    my $type = shift;
    my $name = shift;
    
    return(0) if (!$self->update());
    
    if (!grep(/^\Q$type\E$/, qw(previous normal custom))) {
        $@ = "Invalid type '$type'.";
        return(0);
    }
    
    my ($id);
    if ($type eq 'previous') {
        $id = $self->{'prev_id'};
        $name = "Your Previous Outfit";
    } else {
        if (!exists($self->{'outfits'}{$type}{$name})) {
            $@ = "You do not currently have the outfit '$name'.";
            return(0);
        }
        $id = $self->{'outfits'}{$type}{$name};
    }
    
    # Make the change.
    $self->{'log'}->debug("Changing outfit to '$name'.");
    my $resp = $self->{'session'}->get('inv_equip.php',
    {
        'which'         => 2,
        'action'        => 'outfit',
        'whichoutfit'   => $id,
    });
    return (0) if (!$resp);
    $self->{'session'}->makeDirty();
    
    if ($resp->content() =~ m/<td>You are already wearing .+?\Q$name\E\..+?<\/td>/s) {
        $self->{'log'}->debug("Already wearing '$name'.");
        return(1);
    }
    
    if ($resp->content() !~ m/You put on an Outfit: <b>$name<\/b>/s) {
        $self->{'session'}->logResponse("Unable to change outfit to '$name'.", $resp);
        $@ = "Unable to change outfit to '$name'.";
        return(0);
    }
    
    return(1);
}

sub wearNormal {return($_[0]->wear('normal', $_[1]));}
sub wearCustom {return($_[0]->wear('custom', $_[1]));}
sub wearPrevious {return($_[0]->wear('previous'));}

sub saveOutfit {
    my $self = shift;
    my $name = shift;
    
    # Make the change.
    $self->{'log'}->debug("Changing outfit to '$name'.");
    my $resp = $self->{'session'}->get('inv_equip.php',
    {
        'which'         => 2,
        'action'        => 'customoutfit',
        'outfitname'    => $name,
    });
    return (0) if (!$resp);
    $self->{'session'}->makeDirty();
    
    if ($resp->content() !~ m/Your custom outfit has been saved\./s) {
        $self->{'session'}->logResponse("Unable to save outfit '$name'.", $resp);
        $@ = "Unable to change save outfit '$name'.";
        return(0);
    }
    
    return(1);
}

sub changeName {
    my $self = shift;
    my $old = shift;
    my $new = shift;
    
    return(0) if (!$self->update());
    
    if (exists($self->{'outfits'}{'custom'}{$new})) {
        $@ = "You already have an outfit named '$new'.";
        return(0);
    }
    
    if (!exists($self->{'outfits'}{'custom'}{$old})) {
        $@ = "You do not currently have and outfit named '$old'.";
        return(0);
    }
    my $id = $self->{'outfits'}{'custom'}{$old};
    
    # Make the change.
    $self->{'log'}->debug("Changing outfit name from '$old' to '$new'.");
    my $resp = $self->{'session'}->get('account_manageoutfits.php',
    {
        'action'        => 'Yep.',
        "name$id"       => $new,
    });
    return (0) if (!$resp);
    $self->{'session'}->makeDirty();
    
    if ($resp->content() !~ m/<td>Outfit\(s\) modified\.<\/td>/s) {
        $self->{'session'}->logResponse("Unable to change outfit name " .
                                        "from '$old' to '$new'.", $resp);
        $@ = "Unable to change outfit name from '$old' to '$new'.";
        return(0);
    }
    
    return(1);
}

sub deleteOutfit {
    my $self = shift;
    my $name = shift;
    
    return(0) if (!$self->update());
    
    if (!exists($self->{'outfits'}{'custom'}{$name})) {
        $@ = "You do not currently have and outfit named '$name'.";
        return(0);
    }
    my $id = $self->{'outfits'}{'custom'}{$name};
    
    # Make the change.
    $self->{'log'}->debug("Deleting outfit named '$name'.");
    my $resp = $self->{'session'}->get('account_manageoutfits.php',
    {
        'action'        => 'Yep.',
        "delete$id"       => 'on',
    });
    return (0) if (!$resp);
    $self->{'session'}->makeDirty();
    
    if ($resp->content() !~ m/<td>Outfit\(s\) modified\.<\/td>/s) {
        $self->{'session'}->logResponse("Unable to delete outfit '$name.", $resp);
        $@ = "Unable to change outfit '$name'.";
        return(0);
    }
    
    return(1);
}

1;
