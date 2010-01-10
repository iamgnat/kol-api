# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# TextUtils.pm
#   Class for working with text.

package KoL::TextUtils;

use strict;

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = {
        'columns'   => 80,
        'textwrap'  => 1,
    };
    
    # See if we have Text::Wrap available to us.
    eval {require Text::Wrap;};
    $self->{'textwrap'} = 0 if ($@);
    
    # Get the terminal width if possible, otherwise it should be left at the default.
    if (!-t) {
        # Not a terminal
        $self->{'columns'} = 0;
    } else {
        eval {
            require Term::ReadKey;
            my @terminfo = Term::ReadKey::GetTerminalSize();
            $self->{'columns'} = $terminfo[0] if (@terminfo);
        };
        # Ignore why we couldn't use GTS(), we just care that we can't.
    }
    
    bless($self, $class);
    
    return($self);
}

sub columns {
    my $self = shift;
    return($self->{'columns'});
}

sub setColumns {
    my $self = shift;
    my $val = shift;
    
    return(0) if ($val !~ m/^\d+$/);
    return(0) if ($val < 2);
    
    $self->{'columns'} = $val;
    return($self->columns());
}

sub wrap {
    my $self = shift;
    my $iPad = shift;
    my $sPad = shift;
    my $text = shift;
    
    return($text) if (!$self->{'textwrap'} || $self->{'columns'} <= 0);
    
    $Text::Wrap::columns = $self->{'columns'};
    return(Text::Wrap::wrap($iPad, $sPad, $text));
}

1;
