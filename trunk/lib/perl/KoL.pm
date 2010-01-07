# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# KoL.pm
#   Base class that should contain any general config info or functionality.

package KoL;

use strict;
use Fcntl;
use POSIX;
use Symbol;
use IO::Handle;

our(@ISA, @EXPORT);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(calledFrom promptUser);

my ($_singleton);

sub new {
    my $class = shift;
    my %args = @_;
    
    if (!defined($_singleton)) {
        my $self = {
            'version'   => 'v0_r0_b0',
            'hosts'     => [
                'www.kingdomofloathing.com',
                'www2.kingdomofloathing.com',
                'www3.kingdomofloathing.com',
                'www4.kingdomofloathing.com',
                'www5.kingdomofloathing.com',
                #'www6.kingdomofloathing.com',
                'www7.kingdomofloathing.com',
            ],
            'dirty'     => time(),
        };
        bless($self, $class);
        $_singleton = $self;
    }
    
    return($_singleton);
}

sub version {
    my $self = shift || KoL->new();
    
    return($self->{'version'});
}

sub hosts {
    my $self = shift || KoL->new();
    
    return($self->{'hosts'});
}

sub dirty {
    my $self = shift || KoL->new();
    
    return($self->{'dirty'});
}

sub makeDirty {
    my $self = shift || KoL->new();
    
    $self->{'dirty'} = time();
    return;
}

sub calledFrom {
    my $back = shift || 2;
    
    my $caller = "[Unknown Location]";
    
    my (@info1) = caller($back); # package and name of calling function.
    my (@info2) = caller($back - 1); # The line from the calling function.
    
    if (!@info1) {
        $caller = "main(): $info2[2]";
    } else {
        $caller = "$info1[0]($info1[3]): $info2[2]";
    }
    
    return($caller);
}

# promptUser($msg, $type, $default)
#   Prompts the user for an answer.
#   Args:
#       $msg        - The message to prompt them with.
#       $type       - The variable type of the answer (bool(ean),
#                       int(eger), or string).
#       $default    - The default if they just press enter.
#   Results:
#       Keeps prompting the user for a valid answer and returns it.
#           If they just press enter and a default is supplied, the
#           default value is returned. If contact is lost to STDIN,
#           NULL is returned.
sub promptUser {
    my $prompt = shift;
    my $type = shift;
    my $default = shift;
    
    if (!-t) {
        $@ = "Not a terminal.";
        return(undef);
    }
    
    my ($typeTest);
    if ($type =~ m/^int|^num/i) {
        $typeTest = '^-{0,1}\d+$';
    } elsif ($type =~ m/^bool/i) {
        $type = 'boolean';
        $typeTest = '^[01YyTtNnFf]';
    } elsif ($type =~ m/^str|^pass/i) {
        $typeTest = '.*';
    } else {
        logError("Unknown type '$type'.");
        exit(1);
    }
    
    my $tty = ctermid();
    my $fh = Symbol::gensym();
    if (!open($fh, "+>$tty")) {
        $@ = "Unable to open TTY ($tty): $!";
        return(undef);
    }
    
    my $oldFH = select($fh);
    my $oldPipe = $|;
    select($oldFH);
    
    # Defer signals
    my $osigset = POSIX::SigSet->new();
    my $nsigset = POSIX::SigSet->new(SIGINT, SIGTSTP);
    if (!POSIX::sigprocmask(SIG_BLOCK, $nsigset, $osigset)) {
        $@ = "Unable to change signal mask: $!";
        return(undef);
    }
    
    my $otermios = POSIX::Termios->new();
    my $ntermios = POSIX::Termios->new();
    if (!$otermios->getattr(fileno($fh))) {
        $@ = "Unable to get terminal attributes for TTY: $!";
        return(undef);
    }
    if (!$ntermios->getattr(fileno($fh))) {
        $@ = "Unable to get terminal attributes for TTY: $!";
        return(undef);
    }
    
    # Turn off echoing.
    if ($type =~ m/^password$/) {
        my $c_lflag = $ntermios->getlflag();
        $ntermios->setlflag($c_lflag & ~(ECHO | ECHOE | ECHOK | ECHONL));
        if (!$ntermios->setattr(fileno($fh), TCSAFLUSH)) {
            $@ = "Unable to disable echoing to TTY: $!";
            return(undef);
        }
    }
    
    chomp($prompt);
    $prompt .= " ($default)" if (defined($default));
    
    my ($data, $nread, $error);
    while (!defined($data)) {
        print $fh "$prompt "; # Do not print a new line so the answer is on the same line.
        $fh->flush();
        
        while ($nread = sysread($fh, (my $c), 1)) {
            last if ($c eq "\n");
            $data .= $c;
        }
        print $fh "\n" if ($type =~ m/^password$/); # There newline wasn't displayed.
        
        $data = $default if (!defined($data) && defined($default));
        $data = '' if (!defined($data) && $type =~ m/^str|^pass/i);
        
        if (!defined($nread)) {
            $error = "Unable to read from TTY: $!";
            last;
        }
        if (!defined($data) || $data !~ m/$typeTest/) {
            print $fh "Your answer was not a valid $type. Please try again.\n";
            undef($data);
        }
    }
    
    
    if (!$otermios->setattr(fileno($fh), TCSAFLUSH)) {
        $@ = "Unable to reset TTY settings: $!";
        return(undef);
    }
    
    if (!POSIX::sigprocmask(SIG_SETMASK, $osigset)) {
        $@ = "Unable to reset Signals: $!";
        return(undef);
    }
    
    if (!close($fh)) {
        $@ = "Unable to close TTY handle: $!";
        return(undef);
    }
    
    if (defined($error)) {
        $@ = $error;
        return(undef);
    }
    
    if ($type eq 'boolean') {
        $data = $data =~ m/^[t1y]/i ? 1 : 0;
    }
    
    return($data);
}

1;
