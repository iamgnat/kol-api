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
    
    $log->msg("Processing closet.php.", 15);
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

sub submitForm {
    my $self = shift;
    my $action = shift;
    my %form = @_;
    
    $form{'action'} = $action;
    $form{'pwd'} = $self->{'session'}->pwdhash();
    return($self->{'session'}->post('closet.php', %form));
}

sub putMeat {
    my $self = shift;
    my $meat = shift;
    
    if ($meat !~ m/^\d+$/) {
        $@ = "Invalid value for amount of meat!";
        return(0);
    }
    
    my $resp = $self->submitForm('addmeat', 'amt' => $meat);
    return(0) if (!$resp);
    
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

1;
