# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Item.pm
#   Class representation of an item.

package KoL::Item;

use strict;
use Digest::MD5;
use KoL::Wiki;
use KoL::Item::Accessory;
use KoL::Item::Booze;
use KoL::Item::CombatItem;
use KoL::Item::CraftingItem;
use KoL::Item::FamiliarEquipment;
use KoL::Item::Food;
use KoL::Item::Hat;
use KoL::Item::Misc;
use KoL::Item::OffHandItem;
use KoL::Item::Pants;
use KoL::Item::Potion;
use KoL::Item::Shirt;
use KoL::Item::Usable;
use KoL::Item::Weapon;

my (%_itemCache);

sub new {
    my $class = shift;
    my %args = @_;
    
    if (!exists($args{'controller'})) {
        $@ = "'controller' not suplied in the argument hash!";
        return(undef);
    }
    
    if (!exists($args{'name'}) && !exists($args{'descid'})) {
        $@ = "You must supply either 'name' or 'descid'.";
        return(undef);
    }
    
    my $id = exists($args{'name'}) ? 'name' : 'descid';
    my $key = ":" . $args{'controller'}->{'session'}->user() . ":" .
                $args{$id} . ":" . $args{'controller'}->{'session'} . 
                ":" . $args{'controller'} . ":";
    $key = Digest::MD5::md5_hex($key);
    $args{'controller'}{'session'}{'log'}->debug("Checking cache with '$key'.");
    
    my ($self);
    if (exists($_itemCache{$id}{$key})) {
        $args{'controller'}{'session'}{'log'}->debug("Found cache with.");
        $self = $_itemCache{$id}{$key};
    } else {
        my ($descid);
        if (exists($args{'descid'})) {
            $descid = $args{'descid'};
        } else {
            # Translate the name to the ids.
            my $wiki = KoL::Wiki->new('session' => $args{'controller'}{'session'});
            my $info = $wiki->getItemIds($args{'name'});
            if (!$info) {
                $@ = "Unable to get wiki info for '$args{'name'}': $@";
                return(undef);
            }
            $descid = $info->{'desc'};
            $args{'descid'} = $descid;
        }
    
        # Item description
        my $resp = $args{'controller'}{'session'}->get('desc_item.php',
                                            {'whichitem' => $descid});
        return(undef) if (!$resp);
    
        $args{'content'} = $resp->content();
    
        # Bad item
        if ($args{'content'} =~ m/Invalid description ID/s) {
            $@ = "'$descid' is an invalid item ID.";
            return(undef);
        }
    
        # Get the type
        my $type = ($args{'content'} =~ m/>Type: <b>(.+?)</s) ? $1 : "Misc";
        my $sub = $type;
        if ($sub =~ m/weapon/i) {
            $args{'subtype'} = $type;
            $sub = "Weapon";
        }
        my $mod = 'KoL::Item::';
        $sub =~ s/[^a-z0-9]/ /ig;
    
        foreach my $word (split(/\s+/, $sub)) {
            next if ($word =~ m/^\s*$/);
            $word =~ /^(\S)(.*)$/;
            $mod .= uc($1) . $2;
        }
    
        $self = ${mod}->new(%args);
        
        if (!$self) {
            my $err = $@;
            $args{'controller'}{'session'}->logResponse($err, $resp);
            $@ = $err;
            return(undef);
        }
        
        # Make a hopefully unique key to store the info with.
        my $key1 = ":" . $args{'controller'}->{'session'}->user() . ":" .
                    $self->name() . ":" . $args{'controller'}->{'session'} . 
                    ":" . $args{'controller'} . ":";
        $key1 = Digest::MD5::md5_hex($key1);
        my $key2 = ":" . $args{'controller'}->{'session'}->user() . ":" .
                    $self->descid() . ":" . $args{'controller'}->{'session'} . 
                    ":" . $args{'controller'} . ":";
        $key2 = Digest::MD5::md5_hex($key2);
        
        $args{'controller'}{'session'}{'log'}->debug("Caching " . $self->name() .
                                                    "with '$key1' & '$key2'.");
        $_itemCache{'name'}{$key1} = $self;
        $_itemCache{'descid'}{$key2} = $self;
    }
    
    return($self);
}

1;

