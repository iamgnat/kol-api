# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Character.pm
#   Class for character information

package KoL::Character;

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
        'kol'       => $kol,
        'session'   => $args{'session'},
        'log'       => KoL::Logging->new(),
        'player'    => {},
        'character' => {},
        'skills'    => {},
        'effects'   => {},
        'dirty'     => 0,
    };
    
    bless($self, $class);
    
    return($self);
}

sub dirty {
    my $self = shift;
    
    return($self->{'kol'}->dirty() > $self->{'dirty'});
}

sub update {
    my $self = shift;
    
    if (!$self->{'session'}->loggedIn()) {
        $@ = "You must be logged in to use this method.";
        return(0);
    }
    
    return(1) if (!$self->dirty());
    
    my ($resp);
    $self->{'log'}->debug("Updating character info.");
    
    # Read the character pane
    my $player = {
        'character'     => undef,
        'id'            => undef,
        'created'       => undef,
        'ascensions'    => 0,
        'turns'         => {'total' => 0, 'run' => 0},
        'days'          => {'total' => 0, 'run' => 0},
        'store'         => 0,
        'display'       => 0,
        'food'          => undef,
        'booze'         => undef,
    };
    my $character = {
        'sign'          => undef,
        'path'          => undef,
        'turns'         => 0,
        'meat'          => 0,
        'hp'            => {'max' => 0, 'current' => 0},
        'mp'            => {'max' => 0, 'current' => 0},
        'level'         => {'value' => 0, 'name' => undef},
        'muscle'        => {'buffed' => 0, 'base' => 0},
        'mysticality'   => {'buffed' => 0, 'base' => 0},
        'moxie'         => {'buffed' => 0, 'base' => 0},
        'resistances'    => {
            'cold'      => undef,
            'hot'       => undef,
            'sleaze'    => undef,
            'spooky'    => undef,
            'stench'    => undef,
        },
    };
    my $skills = {};
    my $effects = {};
    
    $self->{'log'}->debug("Processing charsheet.php.");
    $resp = $self->{'session'}->get('charsheet.php');
    return (0) if (!$resp);
    
    my $content = $resp->content();
    
    # Name and number
    if ($content !~ m/href="showplayer.php\?who=(\d+).*?>(.+?)</) {
        $self->{'session'}->logResponse("Unable to locate player name and id", $resp);
        $@ = "Unable to locate player name and id!";
        return(0);
    }
    $player->{'character'} = $2;
    $player->{'id'} = $1;
    
    # Level and level name
    if ($content !~ m/\(#$player->{'id'}\)\s*<br>\s*Level (\d+)\s*<br>([^<]+)<p>/) {
        $self->{'session'}->logResponse("Unable to locate level number and name", $resp);
        $@ = "Unable to locate level number and name!";
        return(0);
    }
    $character->{'level'}{'value'} = $1;
    $character->{'level'}{'name'} = $2;
    
    # Find the current HP value
    if ($content !~ m/Current Hit Points:\s*<\/td>.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate current hp value", $resp);
        $@ = "Unable to locate current hp value!";
        return(0);
    }
    $character->{'hp'}{'current'} = $1;
    $character->{'hp'}{'current'} =~ s/,//g;
    
    # Find the current HP value
    if ($content !~ m/Maximum Hit Points:\s*<\/td>.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate max hp value", $resp);
        $@ = "Unable to locate max hp value!";
        return(0);
    }
    $character->{'hp'}{'max'} = $1;
    $character->{'hp'}{'max'} =~ s/,//g;
    
    # Find the current MP value
    if ($content !~ m/Current M\S+ Points:\s*<\/td>.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate current mp value", $resp);
        $@ = "Unable to locate current mp value!";
        return(0);
    }
    $character->{'mp'}{'current'} = $1;
    $character->{'mp'}{'current'} =~ s/,//g;
    
    # Find the current MP value
    if ($content !~ m/Maximum M\S+ Points:\s*<\/td>.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate max mp value", $resp);
        $@ = "Unable to locate max mp value!";
        return(0);
    }
    $character->{'mp'}{'max'} = $1;
    $character->{'mp'}{'max'} =~ s/,//g;
    
    # Muscle
    if ($content !~ m/Muscle:.+?<b>([\d,]+).+?base: ([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate muscle value", $resp);
        $@ = "Unable to locate muscle value!";
        return(0);
    }
    $character->{'muscle'}{'buffed'} = $1;
    $character->{'muscle'}{'base'} = $2;
    $character->{'muscle'}{'buffed'} =~ s/,//g;
    $character->{'muscle'}{'base'} =~ s/,//g;
    
    # Mysticality
    if ($content !~ m/Mysticality:.+?<b>([\d,]+).+?base: ([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate mysticality value", $resp);
        $@ = "Unable to locate mysticality value!";
        return(0);
    }
    $character->{'mysticality'}{'buffed'} = $1;
    $character->{'mysticality'}{'base'} = $2;
    $character->{'mysticality'}{'buffed'} =~ s/,//g;
    $character->{'mysticality'}{'base'} =~ s/,//g;
    
    # Moxie
    if ($content !~ m/Moxie:.+?<b>([\d,]+).+?base: ([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate moxie value", $resp);
        $@ = "Unable to locate moxie value!";
        return(0);
    }
    $character->{'moxie'}{'buffed'} = $1;
    $character->{'moxie'}{'base'} = $2;
    $character->{'moxie'}{'buffed'} =~ s/,//g;
    $character->{'moxie'}{'base'} =~ s/,//g;
    
    # Elemental resistances
    while ($content =~ m/>(\S+?) Protection:.+?<b>(.+?)</g) {
        $character->{'resistances'}{lc($1)} = $2;
    }
    
    # Turns left today
    if ($content !~ m/Adventures remaining:.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate turns remaining value", $resp);
        $@ = "Unable to locate turns remaining value!";
        return(0);
    }
    $character->{'turns'} = $1;
    $character->{'turns'} =~ s/,//g;
    
    # Meat
    if ($content !~ m/Meat:.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate meat value", $resp);
        $@ = "Unable to locate meat value!";
        return(0);
    }
    $character->{'meat'} = $1;
    $character->{'meat'} =~ s/,//g;
    
    # Favorite Food
    if ($content =~ m/>Favorite Food:.+?<b>(.+?)</) {
        $player->{'food'} = $1;
    }
    
    # Favorite Booze
    if ($content =~ m/>Favorite Booze:.+?<b>(.+?)</) {
        $player->{'booze'} = $1;
    }
    
    # Account created
    if ($content !~ m/Account Created:.+?<b>(.+?)<\/b>/) {
        $self->{'session'}->logResponse("Unable to locate account creation date", $resp);
        $@ = "Unable to locate account creation date!";
        return(0);
    }
    $player->{'created'} = $1;
    
    # Ascensions
    if ($content =~ m/Ascensions:.+?<b>([\d,]+)/) {
        $player->{'ascensions'} = $1;
        $player->{'ascensions'} =~ s/,//g;
    }
    
    # Turns played (total)
    if ($content !~ m/Turns Played[( \(total\))]*:.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate turns played value", $resp);
        $@ = "Unable to locate turns played value!";
        return(0);
    }
    $player->{'turns'}{'total'} = $1;
    $player->{'turns'}{'total'} =~ s/,//g;
    
    # Days Played (total)
    if ($content !~ m/Days Played[( \(total\))]*:.+?<b>([\d,]+)/) {
        $self->{'session'}->logResponse("Unable to locate days played value", $resp);
        $@ = "Unable to locate days played value!";
        return(0);
    }
    $player->{'days'}{'total'} = $1;
    $player->{'days'}{'total'} =~ s/,//g;
    
    # Get Ascension info
    if ($player->{'ascensions'} > 0) {
        # Turns Played (this run)
        if ($content !~ m/Turns Played \(this run\):.+?<b>([\d,]+)/) {
            $self->{'session'}->logResponse("Unable to locate run turns played value", $resp);
            $@ = "Unable to locate run turns played value!";
            return(0);
        }
        $player->{'turns'}{'run'} = $1;
        $player->{'turns'}{'run'} =~ s/,//g;
    
        # Days Played (this run)
        if ($content !~ m/Days Played \(this run\):.+?<b>([\d,]+)/) {
            $self->{'session'}->logResponse("Unable to locate run days played value", $resp);
            $@ = "Unable to locate run days played value!";
            return(0);
        }
        $player->{'days'}{'run'} = $1;
        $player->{'days'}{'run'} =~ s/,//g;
    
        # Sign
        if ($content !~ m/Sign:.+?<b>(.+?)<\/b>/) {
            $self->{'session'}->logResponse("Unable to locate Sign", $resp);
            $@ = "Unable to locate Sign!";
            return(0);
        }
        $character->{'sign'} = $1;
    
        # Path
        if ($content !~ m/Path:.+?<b>(.+?)<\/b>/) {
            $self->{'session'}->logResponse("Unable to locate Path", $resp);
            $@ = "Unable to locate Path!";
            return(0);
        }
        $character->{'path'} = $1;
    }
    
    # Own a store?
    if ($content =~ m/You own a .+?Store/) {
        $player->{'store'} = 1;
    }
    
    # Own a display case?
    if ($content =~ m/You own a .+?Display Case/) {
        $player->{'display'} = 1;
    }
    
    # Effect list
    while ($content =~ m/eff\("(.+?)"\).+?<td.*?>(.+?) \((\d+)\)/g) {
        $effects->{$2} = {
            'name'  => $2,
            'id'    => $1,
            'count' => $3
        };
    }
    
    # Skill list
    while ($content =~ m/desc_skill\.php\?whichskill=(\d+).+?>(.+?)<\/a>(.*?)<br/g) {
        $skills->{$2} = {
            'name'  => $2,
            'id'    => $1,
            'perm'  => $3 ? 1 : 0
        };
    }
    
    # Mark the update time so we know when we need to update again.
    $self->{'dirty'} = time();
    
    $self->{'character'} = $character;
    $self->{'player'} = $player;
    $self->{'skills'} = $skills;
    $self->{'effects'} = $effects;
    
    return(1);
}

1;
