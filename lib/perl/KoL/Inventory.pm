# $Id$

# Inventory.pm
#   Class for working with the inventory.

package KoL::Inventory;

use strict;
use KoL;
use KoL::Logging;
use KoL::Session;

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
        'session'   => $args{'session'},
        'log'       => KoL::Logging->new(),
    };
    
    bless($self, $class);
    
    return($self);
}

sub itemInfo {
    my $self = shift;
    my $id = shift;
    
    if ($id !~ m/^\d+$/) {
        $@ = "Invalid item id '$id'.";
        return(undef);
    }
    
    # If we don't have it or it's been over 12 hours, go get the info.
    if (!exists($_detailsCache{$id}) || time() - $_detailsCache{$id}{'cached'} > 43200) {
        $self->{'log'}->msg("No item info cache for '$id'.", 15);
        
        if (!$self->{'session'}->loggedIn()) {
            $@ = "You must be logged in to use this method.";
            return(0);
        }

        my $resp = $self->{'session'}->get('desc_item.php', {'whichitem' => $id});
        return(undef) if (!$resp);
        
        my $content = $resp->content();
        my %info = (
            'name'          => undef,
            'type'          => 'misc',
            'description'   => undef,
            'tradable'      => 1,
            'discardable'   => 1,
            'meat'          => 0,
            'quest'         => 0,
            'required'      => {
                'muscle'        => 0,
                'mysticality'   => 0,
                'moxie'         => 0,
                'level'         => 0,
            },
            'equipment'     => {
                'power'         => 0,
                'enchantments'  => [],
            }
        );
        
        # Bad item
        if ($content =~ m/Invalid description ID/s) {
            $@ = "'$id' is an invalid item ID.";
            return(undef);
        }
        
        # Get the name
        if ($content !~ m/<center><img.+?<b>(.+?)</s) {
            $self->{'session'}->logResponse("Unable to locate item name", $resp);
            $@ = "Unable to locate item name!";
            return(undef);
        }
        $info{'name'} = $1;
        
        # Get the description
        if ($content !~ m/<blockquote.*?>(.+?)<br><br>/s) {
            $self->{'session'}->logResponse("Unable to locate item name", $resp);
            $@ = "Unable to locate item description!";
            return(undef);
        }
        $info{'description'} = $1;
        
        # Get the type
        $info{'type'} = $1 if ($content =~ m/>Type: <b>(.+?)</s);

        # Power
        $info{'equipment'}{'power'} = $1 if ($content =~ m/>Power: <b>(\d+)</s);
        
        # requirements
        while ($content =~ m/>([Ml].+?) Required: <b>([\d,]+)</igs) {
            my $type = lc($1);
            my $val = $2;
            $val =~ s/,//g;
            $info{'required'}{$type} = $val;
        }
        
        # Selling price
        if ($content =~ m/>Selling Price: <b>([\d,]+) Meat.</s) {
            $info{'meat'} = $1;
            $info{'meat'} =~ s/,//g;
        }
        
        # Non-tradable?
        $info{'tradable'} = 0 if ($content =~ m/Cannot be traded/s);
        
        # Non-discardable?
        $info{'discardable'} = 0 if ($content =~ m/Cannot be discarded/s);
        
        # Quest Item?
        $info{'quest'} = 1 if ($content =~ m/Quest Item/s);
        
        # Enchantments
        if ($content =~ m/>Enchantment:.+?<font.+?>(.+?)<\/font>/s) {
            my $encs = $1;
            while ($encs =~ m/(.+?)<br>/gs) {
                push(@{$info{'equipment'}{'enchantments'}}, $1);
            }
        }
        
        $info{'cached'} = time();
        $_detailsCache{$id} = \%info;
    }
    
    if (exists($_detailsCache{$id})) {
        my %info = %{$_detailsCache{$id}};
        delete($info{'cached'});
        return(\%info);
    }
    
    $@ = "Unable to location '$id'.";
    return(undef);
}

1;
