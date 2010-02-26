# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Misc.pm
#   Class representation of a miscellaneous item.

package KoL::Item::Misc;

use strict;
use KoL;

sub new {
    my $class = shift;
    my %args = @_;
    
    my $content = $args{'content'};
    my $self = {
        'id'                    => $args{'id'},
        'name'                  => undef,
        'descid'                => $args{'descid'},
        'description'           => undef,
        'quest'                 => 0,
        'meat'                  => 0,
        'tradable'              => 1,
        'discardable'           => 1,
        'count'                 => $args{'count'} || 0,
        'controller'            => $args{'controller'},
        'levelRequired'         => 0,
        'moxieRequired'         => 0,
        'muscleRequired'        => 0,
        'mysticalityRequired'   => 0,
    };
    
    # Get the name
    if ($content !~ m/<center><img.+?<b>(.+?)</s) {
        $@ = "Unable to locate item name!";
        return(undef);
    }
    $self->{'name'} = $1;
    
    # Get the description
    if ($content !~ m/<blockquote.*?>(.+?)<br><br>/s) {
        $@ = "Unable to locate item description!";
        return(undef);
    }
    $self->{'description'} = $1;
    
    # Selling price
    if ($content =~ m/>Selling Price: <b>([\d,]+) Meat.</s) {
        $self->{'meat'} = $1;
        $self->{'meat'} =~ s/,//g;
    }
    
    # Non-tradable?
    $self->{'tradable'} = 0 if ($content =~ m/Cannot be traded/s);
    
    # Non-discardable?
    $self->{'discardable'} = 0 if ($content =~ m/Cannot be discarded/s);
    
    # Quest Item?
    $self->{'quest'} = 1 if ($content =~ m/Quest Item/s);
    
    # requirements
    while ($content =~ m/>([Ml].+?) Required: <b>([\d,]+)</igs) {
        my $type = lc($1);
        my $val = $2;
        $val =~ s/,//g;
        $self->{"${type}Required"} = $val;
    }
    
    bless($self, $class);
    
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

sub type {
    my $type = ref($_[0]);
    $type =~ s/^.+?::([^:]+)$/$1/;
    return($type);
}

sub id {return($_[0]->{'id'});}
sub name {return($_[0]->{'name'});}
sub description {return($_[0]->{'description'});}
sub descid {return($_[0]->{'descid'});}
sub tradable {return($_[0]->{'tradable'});}
sub discardable {return($_[0]->{'discardable'});}
sub meat {return($_[0]->{'meat'});}
sub quest {return($_[0]->{'quest'});}
sub count {return($_[0]->getInfo('count'));}
sub muscleRequired {return($_[0]->{'muscleRequired'});}
sub mysticalityRequired {return($_[0]->{'mysticalityRequired'});}
sub moxieRequired {return($_[0]->{'moxieRequired'});}
sub levelRequired {return($_[0]->{'levelRequired'});}

sub setCount {
    my $self = shift;
    my $val = shift || 0;
    
    $self->{'count'} = $val;
    
    return;
}

sub sell {
    my $self = shift;
    my $count = shift || 1;
    
    if (ref($self->{'controller'}) ne 'KoL::Inventory') {
        $@ = "Only inventory items may be sold.";
        return(0);
    }
    
    if (!$self->{'tradable'} || $self->{'quest'}) {
        $@ = "You may not sell this item.";
        return(0);
    }
    
    if ($count !~ m/^\d+$/) {
        $@ = "'$count' is not a valid count.";
        return(0);
    }
    
    if ($count <= 0) {
        $@ = "You have successfully sold zero items.. Really?";
        return(0);
    }
    
    # Use the method rather than a direct check to force an update if needed.
    if ($count > $self->count()) {
        $@ = "You may not sell more than you have.";
        return(0);
    }
    
    my $sess = $self->{'controller'}{'session'};
    my $form = {
        'pwd'           => $sess->pwdhash(),
        'action'        => 'sell',
        'whichitem[]'   => $self->{'id'},
        'type'          => 'quant',
        'howmany'       => $count,
    };
    
    my $resp = $sess->post('sellstuff.php', $form);
    $self->{'controller'}{'session'}->makeDirty();
    return(0) if (!$resp);
    
    if ($resp->content() !~ m/You sell your.+?<td valign=center>You gain ([\d,]+) Meat/s) {
        $sess->logResponse("Unable to sell " . $self->{'name'} . ".", $resp);
        $@ = "Unable to sell item.";
        return(0);
    }
    my $meat = $1;
    $meat =~ s/,//g;
    
    return($meat);
}

sub discard {
    my $self = shift;
    
    if (ref($self->{'controller'}) ne 'KoL::Inventory') {
        $@ = "Only inventory items may be discarded.";
        return(0);
    }
    
    if (!$self->{'discardable'} || $self->{'quest'}) {
        $@ = "You may not discard this item.";
        return(0);
    }
    
    # Use the method rather than a direct check to force an update if needed.
    if ($self->count() == 0) {
        $@ = "You do not have any to discard.";
        return(0);
    }
    
    my $sess = $self->{'controller'}{'session'};
    my $form = {
        'pwd'       => $sess->pwdhash(),
        'action'    => 'discard',
        'whichitem' => $self->{'id'},
    };
    
    my $resp = $sess->post('inventory.php', $form);
    $self->{'controller'}{'session'}->makeDirty();
    return(0) if (!$resp);
    
    if ($resp->content() !~ m/You discard/s) {
        $sess->logResponse("Unable to discard " . $self->{'name'} . ".", $resp);
        $@ = "Unable to discard item.";
        return(0);
    }
    
    return(1);
}

1;
