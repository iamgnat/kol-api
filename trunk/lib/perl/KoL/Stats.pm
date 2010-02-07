# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Stats.pm
#   Class for processing charpane.php and showing the current
#   stats.

package KoL::Stats;

use strict;
use KoL;
use KoL::Logging;
use KoL::Session;

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
        'level'         => 0,
        'title'         => '',
        'muscle'        => {
            'buffed'    => 0,
            'base'      => 0,
        },
        'mysticality'   => {
            'buffed'    => 0,
            'base'      => 0,
        },
        'moxie'         => {
            'buffed'    => 0,
            'base'      => 0,
        },
        'hp'            => {
            'max'       => 0,
            'current'   => 0,
        },
        'mp'            => {
            'max'       => 0,
            'current'   => 0,
        },
        'meat'          => 0,
        'turns'         => 0,
        'last_adv'      => undef,
        'effects'       => {},
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
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(1) if (!$self->dirty());
    
    $self->{'log'}->debug("Processing charpane.php.");
    my $resp = $self->{'session'}->get('charpane.php');
    return (0) if (!$resp);
    
    my $content = $resp->content();
    
    # Level and level name
    if ($content !~ m/<br>Level ([\d,]+)<br>(.+?)</) {
        $self->{'session'}->logResponse("Unable to locate level number and name", $resp);
        $@ = "Unable to locate level number and name!";
        return(0);
    }
    $self->{'level'} = $1;
    $self->{'title'} = $2;
    $self->{'level'} =~ s/,//g;
    
    my ($tmp);
    
    # Muscle
    if ($content !~ m/Muscle:.+?<b>(.+?)<\/b>/s) {
        $self->{'session'}->logResponse("Unable to locate muscle data", $resp);
        $@ = "Unable to locate muscle data!";
        return(0);
    }
    $tmp = $1;
    if ($tmp =~ m/([\d,]+).+?\(([\d,]+)\)/s) {
        $self->{'muscle'}{'buffed'} = $1;
        $self->{'muscle'}{'base'} = $2;
    } elsif ($tmp =~ m/([\d,]+)/s) {
        $self->{'muscle'}{'buffed'} = $1;
        $self->{'muscle'}{'base'} = $1;
    } else {
        $self->{'session'}->logReponse("Unable to locate muscle values.", $resp);
        $@ = "Unable to locate muscle values.";
    }
    $self->{'muscle'}{'buffed'} =~ s/,//g;
    $self->{'muscle'}{'base'} =~ s/,//g;
    
    # Mysticality
    if ($content !~ m/Mysticality:.+?<b>(.+?)<\/b>/s) {
        $self->{'session'}->logResponse("Unable to locate mysticality value", $resp);
        $@ = "Unable to locate mysticality value!";
        return(0);
    }
    $tmp = $1;
    if ($tmp =~ m/([\d,]+).+?\(([\d,]+)\)/s) {
        $self->{'mysticality'}{'buffed'} = $1;
        $self->{'mysticality'}{'base'} = $2;
    } elsif ($tmp =~ m/([\d,]+)/s) {
        $self->{'mysticality'}{'buffed'} = $1;
        $self->{'mysticality'}{'base'} = $1;
    } else {
        $self->{'session'}->logReponse("Unable to locate mysticality values.", $resp);
        $@ = "Unable to locate mysticality values.";
    }
    $self->{'mysticality'}{'buffed'} =~ s/,//g;
    $self->{'mysticality'}{'base'} =~ s/,//g;
    
    # Moxie
    if ($content !~ m/Moxie:.+?<b>(.+?)<\/b>/s) {
        $self->{'session'}->logResponse("Unable to locate moxie value", $resp);
        $@ = "Unable to locate moxie value!";
        return(0);
    }
    $tmp = $1;
    if ($tmp =~ m/([\d,]+).+?\(([\d,]+)\)/s) {
        $self->{'moxie'}{'buffed'} = $1;
        $self->{'moxie'}{'base'} = $2;
    } elsif ($tmp =~ m/([\d,]+)/s) {
        $self->{'moxie'}{'buffed'} = $1;
        $self->{'moxie'}{'base'} = $1;
    } else {
        $self->{'session'}->logReponse("Unable to locate moxie values.", $resp);
        $@ = "Unable to locate moxie values.";
    }
    $self->{'moxie'}{'buffed'} =~ s/,//g;
    $self->{'moxie'}{'base'} =~ s/,//g;
    
    # Find the current HP value
    if ($content !~ m/doc\("hp"\).+?([\d,]+).+?([\d,]+)</s) {
        $self->{'session'}->logResponse("Unable to locate hp values", $resp);
        $@ = "Unable to locate hp values!";
        return(0);
    }
    $self->{'hp'}{'current'} = $1;
    $self->{'hp'}{'max'} = $2;
    $self->{'hp'}{'current'} =~ s/,//g;
    $self->{'hp'}{'max'} =~ s/,//g;
    
    # Find the current MP value
    if ($content !~ m/doc\("mp"\).+?([\d,]+).+?([\d,]+)</s) {
        $self->{'session'}->logResponse("Unable to locate mp values", $resp);
        $@ = "Unable to locate mp values!";
        return(0);
    }
    $self->{'mp'}{'current'} = $1;
    $self->{'mp'}{'max'} = $2;
    $self->{'mp'}{'current'} =~ s/,//g;
    $self->{'mp'}{'max'} =~ s/,//g;
    
    # Meat
    if ($content !~ m/doc\("meat"\).+?([\d,]+)/s) {
        $self->{'session'}->logResponse("Unable to locate meat value", $resp);
        $@ = "Unable to locate meat value!";
        return(0);
    }
    $self->{'meat'} = $1;
    $self->{'meat'} =~ s/,//g;
    
    
    # Turns left today
    if ($content !~ m/doc\("adventures"\).+?([\d,]+)/s) {
        $self->{'session'}->logResponse("Unable to locate turns remaining value", $resp);
        $@ = "Unable to locate turns remaining value!";
        return(0);
    }
    $self->{'turns'} = $1;
    $self->{'turns'} =~ s/,//g;
    
    # Last Adventure
    #href="adventure.php?snarfblat=100">Whitey's Grove</a>
    if ($content =~ m/"adventure\.php\?snarfblat=.+?">(.+?)</s) {
        $self->{'last_adv'} = $1;
    }
    
    # Effect list
    $self->{'effects'} = {};
    while ($content =~ m/eff\("(.+?)"\).+?<td.*?><font.*?>(.+?) \((\d+)\)/gs) {
        $self->{'effects'}{$2} = {
            'name'  => $2,
            'id'    => $1,
            'count' => $3
        };
    }
    
    # Mark the update time so we know when we need to update again.
    $self->{'dirty'} = time();
    
    return(1);
}

sub getInfo {
    my $self = shift;
    my $key = shift;
    $@ = "";
    
    return(undef) if(!$self->update());
    
    return($self->{$key});
}

sub level {return($_[0]->getInfo('level'));}
sub title {return($_[0]->getInfo('title'));}
sub meat {return($_[0]->getInfo('meat'));}
sub turns {return($_[0]->getInfo('turns'));}
sub lastAdventure {return($_[0]->getInfo('last_adv'));}
sub effects {return($_[0]->getInfo('effects'));}

sub muscle {
    return(undef) if(!$_[0]->update());
    return($_[0]->{'muscle'}{'buffed'}, $_[0]->{'muscle'}{'base'});
}

sub mysticality {
    return(undef) if(!$_[0]->update());
    return($_[0]->{'mysticality'}{'buffed'}, $_[0]->{'mysticality'}{'base'});
}

sub moxie {
    return(undef) if(!$_[0]->update());
    return($_[0]->{'moxie'}{'buffed'}, $_[0]->{'moxie'}{'base'});
}

sub hp {
    return(undef) if(!$_[0]->update());
    return($_[0]->{'hp'}{'max'}, $_[0]->{'hp'}{'current'});
}

sub mp {
    return(undef) if(!$_[0]->update());
    return($_[0]->{'mp'}{'max'}, $_[0]->{'mp'}{'current'});
}

1;
