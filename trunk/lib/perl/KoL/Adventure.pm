# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Stats.pm
#   Class for processing charpane.php and showing the current
#   stats.

package KoL::Adventure;

use strict;
use KoL;
use KoL::Logging;
use KoL::Session;

sub new {
    my $class = shift;
    my %args = @_;
    my $kol = KoL->new();
    
    if (!exists($args{'session'})) {
        $@ = "You must supply a session object.";
        return(undef);
    }
    if (!exists($args{'area-id'}) || $args{'area-id'} !~ m/^\d+$/) {
        $@ = "You must supply an area-id.";
        return(undef);
    }
    
    my $self = {
        'kol'       => $kol,
        'session'   => $args{'session'},
        'log'       => KoL::Logging->new(),
        'area-id'   => $args{'area-id'},
        'choices'   => {},
        'callbacks' => {
            'choice'    => undef,
            'action'    => undef,
        }
    };
    
    bless($self, $class);
    
    return($self);
}

sub addChoice {
    my $self = shift;
    my $choice = shift;
    my $option = shift;
    
    if ($choice !~ m/^\d+/ || $option !~ m/^\d+$/) {
        $@ = "choice or option are invalid.";
        return(0);
    }
    
    $self->{'choices'}{$choice} = $option;
    return(1);
}

sub setCallback {
    my $self = shift;
    my $type = shift;
    my $func = shift;
    my $obj = shift;
    
    if (!grep(/^\Q$type\E$/, keys(%{$self->{'callbacks'}}))) {
        $@ = "Invalid callback type '$type'.";
        return(0);
    }
    if (ref($func) ne 'CODE') {
        $@ = "You must supply a code reference as your function.";
        return(0);
    }
    
    my (@args);
    push(@args, $obj) if ($obj);
    push(@args, $func);
    
    $self->{'callbacks'}{$type} = \@args;
    return(1);
}

sub adventure {
    my $self = shift;
    
    my $info = {
        'type'      => 'Unknown',
        'name'      => 'Unknown',
        'results'   => {}
    };
    
    my $form = {'snarfblat' => $self->{'area-id'}};
    my $uri = 'adventure.php';
    
    my $done = 0;
    my $get = 1;
    while (!$done) {
        my ($resp);
        if ($get) {
            print "Getting $uri with " . join(',', %{$form}) . "\n";
            $resp = $self->{'session'}->get($uri, $form);
        } else {
            print "Posting $uri with " . join(',', %{$form}) . "\n";
            $resp = $self->{'session'}->post($uri, $form);
        }
        return(undef) if (!$resp);
        
        my $prev = $resp->previous();
        my $content = $resp->content();
        
        if (!$prev || $prev->code() ne '302') {
            # Non combat
            my $res = $self->processResults($content);
            $info->{'type'} = 'non-combat';
            $info->{'results'} = $res->{'results'};
            $info->{'name'} = $res->{'name'};
            $done = 1;
        } else {
            my $hdrs = $prev->headers();
            
            if ($hdrs->{'location'} =~ m/choice\.php/) {
                # Choice
                if ($content !~ m/<form name=choiceform\d+ action=choice.php method=post>/) {
                    # Choice results
                    my $res = $self->processResults($content);
                    $info->{'type'} = 'choice';
                    $info->{'results'} = $res->{'results'};
                    $info->{'name'} = $res->{'name'};
                    $done = 1;
                } else {
                    # Choose wisely
                    if ($content !~ m/<input type=hidden name=whichchoice value=(\d+)>/s) {
                        $self->{'session'}->logResponse("Unable to locate choice id.", $resp);
                        $@ = "Unable to locate choice id.";
                        return(undef);
                    }
                    my $id = $1;
                    $uri = 'choice.php';
                    $get = 0;
                    $form = {
                        'whichchoice'   => $id,
                        'pwd'           => $self->{'session'}->pwdhash(),
                        'option'        => 0
                    };
                    
                    if (exists($self->{'choices'}{$id})) {
                        # User picked.
                        $form->{'option'} = $self->{'choices'}{$id};
                    } else {
                        # Let's pick one for them.
                        my $choices = 0;
                        while ($content =~ m/name=whichchoice value=\d+><input type=hidden name=option value=(\d+)>/gs) {
                            my $c = $1;
                            $choices = $c if ($c > $choices);
                        }
                        $form->{'option'} = int(rand($choices)) + 1;
                    }
                }
            } elsif ($hdrs->{'location'} =~ m/fight\.php/) {
                # Default to whacking the shit out of it.
                $form = {'action' => 'attack'};
                $uri = 'fight.php';
                $get = 0;
                
                # Process from the previous round/auto-action
                my $res = $self->processResults($content);
                $info->{'win'} = $res->{'win'} if (exists($res->{'win'}));
                $info->{'runaway'} = $res->{'runaway'} if (exists($res->{'runaway'}));
                
                foreach my $key (qw(stuff dealt lost)) {
                    foreach my $sub (keys(%{$res->{$key}})) {
                        if (ref($res->{$key}{$sub}) ne 'HASH') {
                            $info->{$key}{$sub} += $res->{$key}{$sub};
                        } else {
                            foreach my $s (keys(%{$res->{$key}{$sub}})) {
                                $info->{$key}{$sub} += $res->{$key}{$sub};
                            }
                        }
                    }
                }
                
                if (exists($res->{'win'})) {
                    $done = 1;
                    next;
                }
                
                my $runAway = 0;
                my $pickPocket = 0;
                my $special = [];
                if ($content =~ m/value="Pick His Pocket"/s && $pickPocket) {
                    # Pick their pocket.
                    $form = {'action' => 'steal'};
                } elsif (@{$special} && ref($special->[0]) =~ m/^KoL::Item::CombatItem/) {
                    # Use an item
                    
                    my $item = shift(@{$special});
                    $form = {
                        'action'    => 'useitem',
                        'whichitem' => $item->id()
                    };
                    
                    # See about using a second item.
                    if ($content =~ m/<select name=whichitem2>/ &&
                        @{$special} && ref($special->[0]) =~ m/^KoL::Item::CombatItem/) {
                        my $item = shift(@{$special});
                        $form->{'whichitem2'} = $item->id();
                    }
                } elsif (@{$special} && ref($special->[0]) =~ m/^KoL::Skill::Combat/) {
                    # Use a skill
                    my $skill = shift(@{$special});
                    $form = {
                        'action'        => 'skill',
                        'whichskill'    => $skill->id()
                    };
                } elsif ($content =~ m/value="Run Away"/s && $runAway) {
                    # It's only a rabbit!
                    $form = {'action' => 'runaway'};
                }
            } else {
                use Data::Dumper;
                print Dumper($resp);
                $done = 1;
            }
        }
    }
    
    return($info);
}

sub processResults {
    my $self = shift;
    my $content = shift;
    my $results = {};
    my $name = 'Unknown';
    
    if ($content =~ m/Results:<.+?><center><b>(.+?)<\/b>/s) {
        $name = $1;
    } elsif ($content =~ m/<b>Combat.+?<span id='monname'>(.+?)<\/span>/s) {
        $name = $1;
    }
    $name =~ s/<.+?>/ /g;
    $name =~ s/\s/ /g;
    
    # You sissy little coward.
    if ($content =~ m/You run away/s) {
        $results->{'runaway'} = 1;
    } elsif ($content =~ m/You attempt to run away like a sissy little coward/s) {
        $results->{'runaway'} = 0;
    }
    
    # Ouch, that hurt.
    if ($content =~ m/You slink away, dejected and defeated/s) {
        $results->{'win'} = 0;
    }
    
    if ($content =~ m/You lose ([\d,]+) (\S+) point/s) {
        my $points = $1;
        my $type = $2;
        
        $points =~ s/,//g;
        $type = ($type =~ m/^h/i ? 'hp' : 'mp');
        $results->{'lost'}{$type} = $points;
    }
    
    if ($content =~ m/You win the fight/s) {
        $results->{'win'} = 1;
    }
    
    if ($content =~ m/\. ([\d+,]+)(.*?) points worth of blood ooze out of/s ||
        $content =~ m/administer ([\d+,]+)(.*?) points of frozen, sharp damage/s ||
        $content =~ m/also ([\d+,]+)(.*?) damage/s ||
        $content =~ m/and ([\d+,]+)(.*?) damage/s ||
        $content =~ m/at is\. ([\d+,]+)(.*?) points' worth/s ||
        $content =~ m/black, black # ([\d+,]+)(.*?) points of damage/s ||
        $content =~ m/consists of ([\d+,]+)(.*?) whacks/s ||
        $content =~ m/count ([\d+,]+)(.*?) damage/s ||
        $content =~ m/deal\S* ([\d+,]+)(.*?) to your opponent/s ||
        $content =~ m/deal\S* ([\d+,]+)(.*?) damage/s ||
        $content =~ m/did ([\d+,]+)(.*?) damage/s ||
        $content =~ m/do\S* ([\d+,]+)(.*?) damage/s ||
        $content =~ m/doing ([\d+,]+)(.*?) points .+? damage/s ||
        $content =~ m/draining ([\d+,]+)(.*?) points/s ||
        $content =~ m/for ([\d+,]+)(.*?) damage/s ||
        $content =~ m/for ([\d+,]+)(.*?) starchy damage points/s ||
        $content =~ m/for ([\d+,]+)(.*?) oleaginous damage/s ||
        $content =~ m/for ([\d+,]+)(.*?) points' worth of naughtiness/s ||
        $content =~ m/gets ([\d+,]+)(.*?) damage/s ||
        $content =~ m/infernal ([\d+,]+)(.*?) points of damage/s ||
        $content =~ m/inspiring ([\d+,]+)(.*?) points'/s ||
        $content =~ m/just say ([\d+,]+)(.*?) damage/s ||
        $content =~ m/measly ([\d+,]+)(.*?) damage/s ||
        $content =~ m/of ([\d+,]+)(.*?) damage/s ||
        $content =~ m/only ([\d+,]+)(.*?) damage/s ||
        $content =~ m/opponent\. ([\d+,]+)(.*?) damage/s ||
        $content =~ m/person ([\d+,]+)(.*?) damage/s ||
        $content =~ m/raising .+? spear factor by ([\d+,]+)(.*?) points/s ||
        $content =~ m/reaping ([\d+,]+)(.*?) damage/s ||
        $content =~ m/shell out ([\d+,]+)(.*?) damage/s ||
        $content =~ m/Specifically, ([\d+,]+)(.*?) damage's worth/s ||
        $content =~ m/squeeze ([\d+,]+)(.*?) points'/s ||
        $content =~ m/suffer\S+ ([\d+,]+)(.*?) damage/s ||
        $content =~ m/sustain\S+ ([\d+,]+)(.*?) damage/s ||
        $content =~ m/tak\S+ ([\d+,]+)(.*?) .*?damage /s ||
        $content =~ m/takes ([\d+,]+)(.*?) points worth of confusion/s ||
        $content =~ m/taking ([\d+,]+)(.*?) points of.+?precious hit points/s ||
        $content =~ m/tenacious ([\d+,]+)(.*?) damage/s ||
        $content =~ m/the ([\d+,]+)(.*?) damage/s ||
        $content =~ m/Took ([\d+,]+)(.*?) Damage/s ||
        $content =~ m/up ([\d+,]+)(.*?) notches\. BAM/s ||
        $content =~ m/whipping up ([\d+,]+)(.*?) points of really neat, groovy, and hip PAIN/s) {
        my $normal = $1;
        my $extra = $2;
        $normal =~ s/,//g;
        $results->{'dealt'} = {
            'total'     => $normal,
            'normal'    => $normal,
            'hot'       => 0,
            'cold'      => 0,
            'spooky'    => 0,
            'stench'    => 0,
            'sleeze'    => 0,
        };
        
        while ($extra =~ m/<font color=(\S+?)><b>+([\d,]+)<\/b><\/font>/sg) {
            my $type = $1;
            my $amount = $2;
            $amount =~ s/,//g;
            
            if ($type eq 'red') {
                $results->{'dealt'}{'hot'} += $amount;
            } elsif ($type eq 'blue') {
                $results->{'dealt'}{'cold'} += $amount;
            } elsif ($type eq 'gray') {
                $results->{'dealt'}{'spooky'} += $amount;
            } elsif ($type eq 'green') {
                $results->{'dealt'}{'stench'} += $amount;
            } elsif ($type eq 'blueviolet') {
                $results->{'dealt'}{'sleeze'} += $amount;
            } else {
                $results->{'dealt'}{'unknown'}{$type} += $amount;
            }
        }
    }
    
    while ($content =~ m/You (gain|acquire) ([\d,]+) (.+?)(\.|<)/sg) {
        my $val = $2;
        my $thing = $3;
        
        $val =~ s/,//g;
        $results->{'stuff'}{$thing} += $val;
    }
    
    $self->{'log'}->error("Unable to determine name:\n$content") if ($name eq 'Unknown');
    
    return({'name' => $name, 'results' => $results});
}
1;
