# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Familiar.pm
#   Class representation of an individual familiar.

package KoL::Familiar;

use strict;
use Digest::MD5;
use KoL::Logging;

my (%_familiarCache);

sub new {
    my $class = shift;
    my %args = @_;
    
    foreach my $key (qw(id familiars)) {
        next if (exists($args{$key}));
        $@ = "'$key' not suplied in the argument hash!";
        return(undef);
    }
    
    # Make a hopefully unique key to store the info with.
    my $key = ":" . $args{'familiars'}->{'session'}->user() . ":" .
                $args{'id'} . ":" . $args{'familiars'}->{'session'} . 
                ":" . $args{'familiars'} . ":";
    $key = Digest::MD5::md5_hex($key);
    
    my ($self);
    if (exists($_familiarCache{$key})) {
        $self = $_familiarCache{$key}{'obj'};
    } else {
        $self = {
            'key'       => $key,
            'familiars' => $args{'familiars'},
        };
        
        bless($self, $class);
    }
    
    return($@) if (!$self->update(%args));
    
    return($self);
}

sub update {
    my $self = shift;
    my %args = @_;
    
    my $familiar = exists($_familiarCache{$self->{'key'}}{'familiar'}) ?
                    $_familiarCache{$self->{'key'}}{'familiar'} : {};
    
    $args{'exp'} =~ s/,//g if (exists($args{'exp'}));
    $args{'kills'} =~ s/,//g if (exists($args{'kills'}));
    
    $familiar->{'id'} = $args{'id'} if (exists($args{'id'}));
    $familiar->{'name'} = $args{'name'} if (exists($args{'name'}));
    $familiar->{'weight'} = $args{'weight'} if (exists($args{'weight'}));
    $familiar->{'type'} = $args{'type'} if (exists($args{'type'}));
    $familiar->{'exp'} = $args{'exp'} if (exists($args{'exp'}));
    $familiar->{'kills'} = $args{'kills'} if (exists($args{'kills'}));
    $familiar->{'equip'} = $args{'equip'} if (exists($args{'equip'}));
    $familiar->{'current'} = $args{'current'} if (exists($args{'current'}));
    
    $_familiarCache{$self->{'key'}}{'obj'} = $self;
    $_familiarCache{$self->{'key'}}{'familiar'} = $familiar;
    
    return(1);
}

sub delete {
    my $self = shift;
    
    delete($_familiarCache{$self->{'key'}}{'familiar'});
}

sub exists {
    my $self = shift;
    
    return(0) if (!$self->{'familiars'}->update());
    return(exists($_familiarCache{$self->{'key'}}{'familiar'}));
}

sub _getInfo {
    my $self = shift;
    my $key = shift;
    $@ = "";
    
    return (undef) if (!$self->exists());
    return($_familiarCache{$self->{'key'}}{'familiar'}{$key});
}

sub id {return($_[0]->_getInfo('id'));}
sub name {return($_[0]->_getInfo('name'));}
sub weight {return($_[0]->_getInfo('weight'));}
sub type {return($_[0]->_getInfo('type'));}
sub exp {return($_[0]->_getInfo('exp'));}
sub kills {return($_[0]->_getInfo('kills'));}
sub equip {return($_[0]->_getInfo('equip'));}
sub isCurrent {return($_[0]->_getInfo('current'));}

1;

