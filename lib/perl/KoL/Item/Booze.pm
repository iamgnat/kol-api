# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Booze.pm
#   Class representation of a booze item.

package KoL::Item::Booze;

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

sub drink {
    my $self = shift;
    my $count = shift || 1;
    
    if (ref($self->{'controller'}) ne 'KoL::Inventory') {
        $@ = "Only inventory items may be drunk.";
        return(undef);
    }
    
    if (!$self->{'tradable'} || $self->{'quest'}) {
        $@ = "You may not drink this item.";
        return(undef);
    }
    
    if ($count !~ m/^\d+$/) {
        $@ = "'$count' is not a valid count.";
        return(undef);
    }
    
    if ($count <= 0) {
        $@ = "You have successfully drunk zero items.. Really?";
        return(undef);
    }
    
    # Use the method rather than a direct check to force an update if needed.
    if ($count > $self->count()) {
        $@ = "You may not drink more than you have.";
        return(undef);
    }
    
    my $sess = $self->{'controller'}{'session'};
    my $form = {
        'pwd'           => $sess->pwdhash(),
        'which'         => 1,
        'whichitem'     => $self->{'id'},
        'quantity'      => $count,
    };
    
    my $resp = $sess->post('inv_booze.php', $form);
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
