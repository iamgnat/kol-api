# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Closet.pm
#   Class for dealing with the Closet

package KoL::Closet;

use strict;
use KoL;
use KoL::Logging;
use KoL::Session;
use KoL::Item;

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
        'meat'      => 0,
        'items'     => {},
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
    
    $@ = '';
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(1) if (!$self->dirty() && !$resp);
    
    $log->debug("Updating Closet info.");
    
    # Reset items that are/were in the closet to a count of 0.
    foreach my $id (keys(%{$self->{'items'}})) {
        $self->{'items'}{$id}->setCount(0);
    }
    
    $log->debug("Processing closet.php.");
    $resp = $self->{'session'}->get('closet.php') if (!$resp);
    return (0) if (!$resp);
        
    my $content = $resp->content();
    
    # Get the stored meat
    if ($content !~ m/Your closet contains ([\d,]+) meat/s) {
        $self->{'session'}->logResponse("Unable to locate current meat!", $resp);
        $@ = "Unable to locate current meat amount.";
        return(0);
    }
    $self->{'meat'} = $1;
    
    if ($content !~ m/Though your Closet is without bounds, it contains no items/s) {
        # Get contents of closet.
        if ($content !~ m/<form.*?name="takegoodies".*?>(.*?)<\/form>/s) {
            $self->{'session'}->logResponse("Unable to find items in closet!", $resp);
            $@ = "Unable to find items in closet.";
            return(0);
        }
        my $ic = $1;
        
        while ($ic =~ m/<option value='(.+?)' descid='(.+?)'>.*?\(([\d,]+?)\)<\/option>/sg) {
            my $id = $1;
            my $descid = $2;
            my $count = 3;
            
            my ($item);
            if (exists($self->{'items'}{$id})) {
                $item = $self->{'items'}{$id};
            } else {
                $item = KoL::Item->new('controller' => $self, 'descid' => $descid);
                return(0) if (!$item);
            }
            
            $item->setCount($count);
        }
    }
    
    # Mark the update time so we know when we need to update again.
    $self->{'dirty'} = $self->{'kol'}->time();
    
    return(1);
}

sub meat {
    my $self = shift;
    $@ = '';
    
    return(-1) if (!$self->update());
    return($self->{'meat'});
}

sub items {
    my $self = shift;
    $@ = '';
    
    return(-1) if (!$self->update());
    
    my (%items);
    foreach my $name (keys(%{$self->{'items'}})) {
        next if ($self->{'items'}{$name}->count() == 0);
        $items{$name} = $self->{'items'}{$name};
    }
    return(\%items);
}

sub submitForm {
    my $self = shift;
    my $action = shift;
    my %form = @_;
    
    $form{'action'} = $action;
    $form{'pwd'} = $self->{'session'}->pwdhash();
    return($self->{'session'}->post('closet.php', \%form));
}

sub putMeat {
    my $self = shift;
    my $meat = shift;
    
    if ($meat !~ m/^\d+$/) {
        $@ = "Invalid value for amount of meat!";
        return(0);
    }
    
    return(1) if ($meat == 0);
    
    my $resp = $self->submitForm('addmeat', 'amt' => $meat);
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked but we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
    if ($resp->content() !~ m/You put ([\d,]+) Meat in your closet/) {
        $self->{'session'}->logResponse("Meat apparently not added.", $resp);
        $@ = "Meat was not added to closet.";
        return(0);
    }
    my $m = $1;
    $m =~ s/,//g;
    
    if ($m != $meat) {
        $@ = "Only $m meat was put into the closet!";
        return(0);
    }
    
    return($self->update($resp));
}

sub takeMeat {
    my $self = shift;
    my $meat = shift;
    
    if ($meat !~ m/^\d+$/) {
        $@ = "Invalid value for amount of meat!";
        return(0);
    }
    
    return(1) if ($meat == 0);
    return(0) if ($self->dirty() && !$self->update());
    
    $meat = $self->{'meat'} if ($meat > $self->{'meat'});
    
    my $resp = $self->submitForm('takemeat', 'amt' => $meat);
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked but we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
    if ($resp->content() !~ m/You take ([\d,]+) Meat out of your closet/) {
        $self->{'session'}->logResponse("Meat apparently not removed.", $resp);
        $@ = "Meat was not removed from your closet.";
        return(0);
    }
    my $m = $1;
    $m =~ s/,//g;
    
    if ($m != $meat) {
        $@ = "Only $m meat was removed from the closet!";
        return(0);
    }
    
    return($self->update($resp));
}

sub putItems {
    my $self = shift;
    my @items = @_;
    
    return(1) if (!@items);
    
    if (@items > 11) {
        $@ = "You may only put 11 items in the closet at one time.";
        return(0);
    }
    
    my (%form, @checks);
    for (my $i = 0 ; $i < @items ; $i++) {
        my $item = undef;
        my $count = 0;
        my $ref = ref($items[$i]);
        
        if ($ref =~ m/^KoL::Item::.+$/) {
            $item = $items[$i];
        } elsif ($ref eq 'ARRAY') {
            if (ref($items[$i][0]) !~ m/^KoL::Item::.+$/) {
                $@ = "First element of $i is not an Item instance!";
                return(0);
            }
            $item = $items[$i][0];
            
            if (@{$items[$i]} > 1) {
                $count = $items[$i][1];
                $count =~ s/,//g;
                if ($count !~ m/^\d+$/) {
                    $@ = "The count supplied for $i is not valid!";
                    return(0);
                }
            }
        } else {
            $@ = "Don't know what to do with element $i of your arguments!";
            return(0);
        }
        
        if ($item->{'controller'} == $self) {
            $@ = "Item for element $i is a closet item.";
            return(0);
        }
        
        $count = $item->count() if ($count == 0);
        next if (!$count);
        
        $form{'howmany' . ($i + 1)} = $count;
        $form{'whichitem' . ($i + 1)} = $item->id();
        push(@checks, $item->name());
    }
    use Data::Dumper;
    print "Put items form:\n" . Dumper(%form);
    
    my $resp = $self->submitForm('put', %form);
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked but we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
    $@ = '';
    my (@err);
    foreach my $item (@checks) {
        if ($resp->content() !~ m/$item.+? moved from inventory to closet/s) {
            push(@err, $item);
        }
    }
    if (@err) {
        $self->{'session'}->logResponse("Items not put in closet!", $resp);
        $@ = "The following items were not put into the closet: " .
                join(', ', @err);
        return(0);
    }
    
    return($self->update($resp));
}

sub takeItems {
    my $self = shift;
    my @items = @_;
    
    return(1) if (!@items);
    
    if (@items > 11) {
        $@ = "You may only take 11 items from the closet at one time.";
        return(0);
    }
    
    my (%form, @checks);
    for (my $i = 0 ; $i < @items ; $i++) {
        my $item = undef;
        my $count = 0;
        my $ref = ref($items[$i]);
        
        if ($ref =~ m/^KoL::Item::.+$/) {
            $item = $items[$i];
        } elsif ($ref eq 'ARRAY') {
            if (ref($items[$i][0]) !~ m/^KoL::Item::.+$/) {
                $@ = "First element of $i is not an Item instance!";
                return(0);
            }
            $item = $items[$i][0];
            
            if (@{$items[$i]} > 1) {
                $count = $items[$i][1];
                $count =~ s/,//g;
                if ($count !~ m/^\d+$/) {
                    $@ = "The count supplied for $i is not valid!";
                    return(0);
                }
            }
        } else {
            $@ = "Don't know what to do with element $i of your arguments!";
            return(0);
        }
        
        if ($item->{'controller'} != $self) {
            $@ = "Item for element $i is not a closet item.";
            return(0);
        }
        
        $count = $item->count() if ($count == 0);
        next if (!$count);
        
        $form{'howmany' . ($i + 1)} = $count;
        $form{'whichitem' . ($i + 1)} = $item->id();
        push(@checks, $item->name());
    }
    
    my $resp = $self->submitForm('take', %form);
    return(0) if (!$resp);
    
    # Make it dirty now just incase the change really worked but we
    #   don't know it for some reason.
    $self->{'kol'}->makeDirty();
    
    $@ = '';
    my (@err);
    foreach my $item (@checks) {
        if ($resp->content() !~ m/<b>$item \(.+?\) moved from closet to inventory/s) {
            push(@err, $item);
        }
    }
    if (@err) {
        $@ = "The following items were not put into the closet: " .
                join(', ', @err);
        return(0);
    }
    
    return($self->update($resp));
}

1;
