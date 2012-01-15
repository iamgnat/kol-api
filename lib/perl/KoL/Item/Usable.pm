# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Usable.pm
#   Class representation of a usable item.

package KoL::Item::Usable;

use strict;
use base qw(KoL::Item::Misc);

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = KoL::Item::Misc->new(%args);
    return(undef) if (!$self);
    
    bless($self, $class);
    
    return($self);
}

sub use {
    my $self = shift;
    my $count = shift || 1;
    
    if (ref($self->{'controller'}) ne 'KoL::Inventory') {
        $@ = "Only inventory items may be used.";
        return(undef);
    }
    
    if ($count !~ m/^\d+$/) {
        $@ = "'$count' is not a valid count.";
        return(undef);
    }
    
    # Use the method rather than a direct check to force an update if needed.
    if ($count > $self->count()) {
        $@ = "You may not use more than you have.";
        return(undef);
    }
    
    my $sess = $self->{'controller'}{'session'};
    my $form = {
        'action'        => 'useitem',
        'pwd'           => $sess->pwdhash(),
        'which'         => 3,
        'whichitem'     => $self->{'id'},
        'quantity'      => $count,
    };
    
    my $resp = $sess->post('inv_use.php', $form);
    $self->{'controller'}{'session'}->makeDirty();
    return(undef) if (!$resp);
    
    my $results = {};
    my $content = $resp->content();
    while ($content =~ m/You (gain|acquire) ([\d,]+) (.+?)\./sg) {
        my $val = $2;
        my $thing = $3;
        
        $val =~ s/,//g;
        $results->{$thing} += $val;
    }
    
    return($results);
}

1;
