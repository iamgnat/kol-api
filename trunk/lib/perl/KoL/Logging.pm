# $Id$

# Logging.pm
#   David Whittle 12/03/2009
#   Class for writing log messages.

package KoL::Logging;

use strict;
use POSIX;
use KoL;
use KoL::FileUtils;
use KoL::TextUtils;

my ($_singleton);

sub new {
    my $class = shift;
    my %args = @_;
    
    if (!defined($_singleton)) {
        my $self = {
            'text'      => KoL::TextUtils->new(),
            'handles'   => {
                'debug' => [\*STDERR],
                'error' => [\*STDERR],
                'msg'   => [\*STDOUT]
            },
            'date_fmt'  => '%Y/%m/%d %H:%M:%S',
            'debug'     => 0,
            'verbosity' => 1,
            'pad'       => 4
        };
    
        bless($self, $class);
        $_singleton = $self;
    }
    
    $_singleton->setDebugHandles($args{'debugHandles'}) if (exists($args{'debugHandles'}));
    $_singleton->setErrorHandles($args{'errorHandles'}) if (exists($args{'errorHandles'}));
    $_singleton->setMsgHandles($args{'msgHandles'}) if (exists($args{'msgHandles'}));
    $_singleton->setTimestampFormat($args{'date_fmt'}) if (exists($args{'date_fmt'}));
    $_singleton->setDebug($args{'debug'}) if (exists($args{'debug'}));
    $_singleton->setVerbosity($args{'verbosity'}) if (exists($args{'verbosity'}));
    $_singleton->setWrapPad($args{'pad'}) if (exists($args{'pad'}));
    $_singleton->setupCLI($args{'cli'}) if (exists($args{'cli'}));
    
    return($_singleton);
}

sub setupCLI {
    my $self = shift;
    my $cli = shift;
    $cli->addOption(
        'name'          => 'debug',
        'type'          => 'boolean',
        'short-name'    => 'd',
        'description'   => 'Enables/Disables printing of debug messages.',
        'default'       => $self->debugging(),
        'callback'      => [$self, \&optionCallback]
    );
    $cli->addOption(
        'name'          => 'verbose',
        'type'          => 'number',
        'short-name'    => 'v',
        'description'   => 'Changes the verbosity of log messages.',
        'default'       => 1,
        'callback'      => [$self, \&optionCallback]
    );
    
    return;
}
    
sub optionCallback {
    my $self = shift;
    my $cli = shift;
    my $opt = shift;
    my $val = shift;
    
    if ($opt eq 'debug') {
        $self->setDebug($val);
    } elsif ($opt eq 'verbose') {
        $self->setVerbosity($val);
    } else {
        $self->error("Unknown option '$opt' given to CLI callback. Ignoring.");
    }
    
    return;
}

sub setDebugHandles {
    my $self = shift;
    my $handles = shift;
    
    return($self->_setHandles('debug', $handles));
}

sub setErrorHandles {
    my $self = shift;
    my $handles = shift;
    
    return($self->_setHandles('error', $handles));
}

sub setMsgHandles {
    my $self = shift;
    my $handles = shift;
    
    return($self->_setHandles('msg', $handles));
}

sub setTimestampFormat {
    my $self = shift;
    my $fmt = shift;
    
    $self->{'date_fmt'} = $fmt;
    return;
}

sub setDebug {
    my $self = shift;
    my $value = shift || 0;
    
    $self->{'debug'} = ($value =~ m/^[1yt]/i) ? 1 : 0;
    return;
}

sub debugging {
    my $self = shift;
    return($self->{'debug'});
}

sub setVerbosity {
    my $self = shift;
    my $value = shift || 1;
    
    $self->{'verbosity'} = $value if ($value =~ m/^\d+/);
    return;
}

sub verbosity {
    my $self = shift;
    return($self->{'verbosity'});
}

sub setWrapPad {
    my $self = shift;
    my $value = shift || 0;
    
    $self->{'pad'} = $value if ($value =~ m/^\d+/);
    return;
}

sub debug {
    my $self = shift;
    my $msg = shift;
    
    return(1) if (!$self->{'debug'});
    return($self->_writeMsg('debug', "DEBUG: " . calledFrom() . ": $msg"));
}

sub error {
    my $self = shift;
    my $msg = shift;
    
    return($self->_writeMsg('error', "ERROR: $msg"));
}

sub msg {
    my $self = shift;
    my $msg = shift;
    my $level = shift || 1;
    
    return(1) if ($level > $self->{'verbosity'});
    return($self->_writeMsg('msg', $msg));
}

sub _setHandles {
    my $self = shift;
    my $type = shift;
    my $handles = shift;
    
    my (@refs);
    if (ref($handles) eq 'ARRAY') {
        for (my $i = 0 ; $i < @{$handles} ; $i++) {
            if (ref($handles->[$i]) ne 'GLOB') {
                print STDERR "ERROR: " . calledFrom(3) . ": $type handle " . ($i + 1) .
                                " is not a GLOB! Skipping\n";
                next;
            }
            push(@refs, $handles->[$i]);
        }
    } elsif (ref($handles) eq 'GLOB') {
        push(@refs, $handles);
    } else {
        print STDERR "ERROR: " . calledFrom(3) .
                        ": $type handle is not a GLOB or Array ref of GLOBs!\n";
    }
    
    if (!@refs) {
        print STDERR "ERROR: " . calledFrom(3) .
                        ": No file handles set for '$type' logging! " .
                        "Logging for this type will be disabled!\n";
    }
    $self->{'handles'}{$type} = \@refs;
    
    return;
}

sub _writeMsg {
    my $self = shift;
    my $type = shift;
    my $msg = shift;
    
    if (!exists($self->{'handles'}{$type})) {
        print STDERR _calledFrom(3) . ": Unknown log type '$type'. Unable to log message!\n";
        return(0);
    }
    
    my $ts = $self->_formatTime();
    foreach my $fh (@{$self->{'handles'}{$type}}) {
        if (!-t $fh) {
            # Not a terminal, don't wrap it.
            print $fh "$ts $msg\n";
        } else {
            # It's a terminal, let's hope we can wrap.
            print $fh $self->{'text'}->wrap('', sprintf("%" . $self->{'pad'} . "s", ' '),
                                            "$ts $msg") . "\n";
        }
    }
    
    return(1);
}

sub _formatTime {
    my $self = shift;
    my $time = shift || 0;
    
    my @time = $time ? localtime($time) : localtime();
    return(strftime($self->{'date_fmt'}, @time));
}

1;
