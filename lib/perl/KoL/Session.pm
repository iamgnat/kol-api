# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# Session.pm
#   Class for handling HTTP requests to KoL in the context of a session.

package KoL::Session;

use strict;
use LWP;
use LWP::UserAgent;
use Digest::MD5;
use URI::Escape;
use Time::HiRes;
use KoL;
use KoL::Stats;
use KoL::Logging;
use KoL::FileUtils;

sub new {
    my $class = shift;
    my %args = @_;
    my $kol = KoL->new();
    
    # Defaults.
    $args{'agent'} = 'KoLAPI/' . $kol->version() if (!exists($args{'agent'}));
    $args{'timeout'} = 60 if (!exists($args{'timeout'}));
    $args{'server'} = $kol->host() if (!exists($args{'server'}));
    
    if (!exists($args{'email'})) {
        $@ = "You must supply an email address.";
        return(undef);
    }
    
    my $self = {
        'kol'           => $kol,
        'agent'         => $args{'agent'},
        'timeout'       => $args{'timeout'},
        'email'         => $args{'email'},
        'server'        => $args{'server'},
        'lwp'           => undef,
        'sessionid'     => undef,
        'pwdhash'       => undef,
        'user'          => undef,
        'log'           => KoL::Logging->new(),
        'no_dos'        => {
            'second'    => 0,
            'count'     => 0,
        },
        'last_resp'     => undef,
        'stats'         => undef,
        'dirty'         => Time::HiRes::time(),
    };
    
    bless($self, $class);
    
    $self->{'log'}->debug("Configuring LWP with '" . $self->{'agent'} . 
                "' and a timeout of " . $self->{'timeout'} . " seconds.");
    $self->{'lwp'} = LWP::UserAgent->new(
        'agent'                 => $self->{'agent'},
        'from'                  => $self->{'email'},
        'cookie_jar'            => {},
        'requests_redirectable' => ['HEAD', 'GET', 'POST'],
        'timeout'               => $self->{'timeout'},
    );
    
    return($self);
}

sub dirty {
    my $self = shift;
    
    return($self->{'dirty'});
}

sub time {
    return(Time::HiRes::time());
}

sub makeDirty {
    my $self = shift;
    
    # Standard seconds weren't good enough. Sleep for 100th of a
    #   second (or smallest amount for the platform) so we know
    #   there will be a difference when comparing against it.
    $self->{'dirty'} = $self->time();
    Time::HiRes::sleep(0.01);
    
    return;
}

sub loggedIn {
    my $self = shift;
    
    return(0) if (!$self->{'sessionid'});
    return(1);
}

sub sessionID {
    my $self = shift;
    
    return($self->{'sessionid'});
}

sub pwdhash {
    my $self = shift;
    
    return($self->{'pwdhash'});
}

sub user {
    my $self = shift;
    
    return($self->{'user'});
}

sub lock {
    my $self = shift;
    my $user = shift;
    
    my $lock = "/tmp/kol.$user.lock";
    if (-e $lock) {
        my $pid = KoL::FileUtils::readFile($lock) || 0;
        if ($pid ne $$) {
            $@ = "'$user' appears to already be in use by another process.";
            return(0);
        }
    } else {
        if (!KoL::FileUtils::writeFile($lock, $$)) {
            $@ = "Unable to create lock file for '$user': $@";
            return(0);
        }
    }
    
    return(1);
}

sub _unlock {
    my $self = shift;
    my $user = shift;
    
    my $lock = "/tmp/kol.$user.lock";
    my $pid = KoL::FileUtils::readFile($lock) || 0;
    if ($pid eq $$ && !unlink($lock)) {
        $@ = "Unable to remove lock file: $!";
        return(0);
    }
    return(1);
}

sub login {
    my $self = shift;
    my $user = shift;
    my $pass = shift;
    
    return(1) if ($self->{'sessionid'});
    return(0) if (!$self->lock($user));
    
    if (!$pass) {
        if (!-t) {
            $self->_unlock($user);
            $@ = "No password supplied for '$user' and this is not an " .
                    "interactive terminal.";
            return(0);
        }
        $pass = KoL::promptUser("Enter password for '$user':", 'password');
        if (!$pass) {
            $self->_unlock($user);
            $@ = "Unable to get password from user: $@";
            return(0);
        }
    }
    
    my ($resp);
    $self->{'log'}->debug("Logging in as '$user'...");
    
    # Get the hash key for hashing the password.
    #   Disable redirects so we can get the key.
    $resp = $self->get('login.php');
    if (!$resp) {
        my $msg = $@;
        $self->_unlock($user);
        $@ = $msg;
        return(0);
    }
    
    # Did we redirect?
    if (!$resp->previous()) {
        $self->_unlock($user);
        $self->logResponse("Login page did not redirect", $resp);
        $@ = "Login page did not redirect: " . $resp->status_line();
        return(0);
    }
    
    # Did we get the login page?
    if ($resp->content() !~ m/Enter the Kingdom/s) {
        $self->_unlock($user);
        $self->logResponse("Did not get the login page", $resp);
        $@ = "Did not get the login page: " . $resp->status_line();
        return(0);
    }
    
    # Get the new URI.
    if ($resp->previous()->header('Location') !~ m/(login\.php\?loginid=\S+)/s) {
        $self->_unlock($user);
        $self->logResponse("Unable to get login URI", $resp);
        $@ = "Unable to get login URI: " . $resp->status_line();
        return(0);
    }
    my $loginURI = $1;
    
    # Get the challenge hash key
    if ($resp->content() !~ m/<input.+?name=["']*challenge["']*.+?value=["']*([^"'\s>]+)["'\s>]/s) {
        $self->_unlock($user);
        $self->logResponse("Unable to get the challenge hash key", $resp);
        $@ = "Unable to get the challenge hash key: " . $resp->status_line();
        return(0);
    }
    my $hashKey = $1;
    
    # Hash the password.
    $pass = Digest::MD5::md5_hex(Digest::MD5::md5_hex($pass) . ":$hashKey");
    
    $resp = $self->post($loginURI, {
        'loggingin' => 'Yup.',
        'loginname' => $user,
        'password'  => '',
        'challenge' => $hashKey,
        'secure'    => 1,
        'response'  => $pass
    });
    if (!$resp) {
        my $msg = $@;
        $self->_unlock($user);
        $@ = $msg;
        return(0);
    }
    
    if ($resp->content() =~ m/Login failed/s) {
        $self->_unlock($user);
        $@ = "Bad username or password.";
        return(0);
    }
    
    if ($resp->content() =~ m/Too many login attempts/s) {
        $self->_unlock($user);
        $@ = "Too many recent login attempts.";
        return(0);
    }
        
    $self->{'log'}->debug("Login request successful, processing results.");
    my $cookies = $self->{'lwp'}->cookie_jar()->as_string();
    $self->{'log'}->debug("Cookies:\n$cookies");
    if ($cookies !~ m/.*PHPSESSID\=(\w*).*/s) {
        $self->_unlock($user);
        $self->logResponse("Unable to locate session id after login as '$user'", $resp);
        $@ = "Unable to locate session id.";
        return(0);
    }
    
    $self->{'sessionid'} = $1;
    $self->{'user'} = $user;
    
    $resp = $self->get('charpane.php');
    if (!$resp) {
        my $msg = $@;
        $self->_unlock($user);
        $@ = $msg;
        return(0);
    }
    
    if ($resp->content() !~ m/var pwdhash = "(.+?)"/s) {
        $self->_unlock($user);
        $self->logResponse("Unable to locate pwdhash", $resp);
        $@ = "Unable to locate pwdhash!";
        return(0);
    }
    $self->{'pwdhash'} = $1;
    
    $self->makeDirty();
    
    $self->{'stats'} = KoL::Stats->new('session' => $self);
    $self->{'stats'}->update($resp);
    
    return(1);
}

sub logout {
    my $self = shift;
    
    return(1) if (!$self->{'sessionid'});
    
    my $user = $self->{'user'};
    my $resp = $self->get('logout.php');
    if (!$resp && $@ !~ m/Nightly Maintenance|logged out/is) {
        $@ = "Unable to logout '" . $self->{'user'} . "': $@";
        return(0);
    }
    
    return(0) if (!$self->_unlock($user));
    
    $self->makeDirty();
    
    $self->{'sessionid'} = undef;
    $self->{'user'} = undef;
    $self->{'stats'} = undef;
    
    if (!$resp) {
        $self->{'log'}->debug("Logout by system.");
        return(1);
    }
    
    if ($resp->content() !~ m/Logged Out/s) {
        $self->{'log'}->error("'$user' may not have been logged out as expected!");
        $self->logResponse("'$user' may not have been logged out as expected!", $resp);
    }
    return(1);
}

sub _processResponse {
    my $self = shift;
    my $resp = shift;
    
    $self->{'last_resp'} = $resp;
    
    # Simple record keeping to cut down on DoS like usage.
    if ($self->{'no_dos'}{'second'} != CORE::time()) {
        $self->{'no_dos'}{'second'} = CORE::time();
        $self->{'no_dos'}{'count'} = 0
    }
    $self->{'no_dos'}{'count'}++;
    
    # HTTP failure
    if (!$resp->is_success()) {
        $@ = $resp->status_line;
        return(undef);
    }
    
    # Down for maintenance.
    if ($resp->content() =~ m/Nightly Maintenance/s) {
        $@ = "KoL is down for Nightly Maintenance.";
        return(undef);
    }
    
    # If we were redirected, update our server.
    my $prev = $resp->previous();
    if ($prev && $prev->code() eq '302') {
        my $hdrs = $prev->headers();
        if ($hdrs->{'location'} eq 'maint.php') {
            $@ = "KoL is down for Nightly Maintenance.";
            return(undef);
        }
        if ($hdrs->{'location'} eq 'loggedout.php') {
            $self->{'sessionid'} = undef;
            $self->{'user'} = undef;
            $@ = "You have been logged out.";
            return(undef);
        }
        if ($hdrs->{'location'} =~ m%http://([^/]+)/%s) {
            $self->{'log'}->debug("We were redirected, but can't process '" .
                                    $hdrs->{'location'} . "'.");
            $self->{'server'} = $1 if ($1 ne $self->{'server'});
        }
    }
    
    return($resp);
}

sub request {
    my $self = shift;
    my $type = shift;
    my $uri = shift;
    my $form = shift;
    my $headers = shift;
    
    $type = lc($type);
    if (!grep(/^\Q$type\E$/, ('get', 'head', 'post'))) {
        $@ = "Unknown request type '$type'!";
        return(0);
    }
    
    # Figure out form data and method args.
    my (@args);
    if ($type eq 'post') {
        push(@args, $form) if ($form);
        push(@args, $headers) if ($headers);
    } elsif ($type =~ m/get|head/ && ref($form) eq 'HASH') {
        my (@qry);
        foreach my $opt (keys(%{$form})) {
            my $key = URI::Escape::uri_escape($opt);
            my $val = URI::Escape::uri_escape($form->{$opt});
            push(@qry, "$key=$val");
        }
        $uri .= '?' . join('&', @qry);
        push(@args, $headers) if ($headers);
    }
    
    # Place nice and try not to DoS KoL.
    sleep(1) if (CORE::time() - $self->{'no_dos'}{'second'} < 1 &&
                    $self->{'no_dos'}{'count'} >= 30);
    
    my $url = 'http://' . $self->{'server'} . "/$uri";
    $self->{'log'}->debug("'$type' request for '$url'.");
    return($self->_processResponse($self->{'lwp'}->$type($url, @args)));
}

sub get {
    my $self = shift;
    return($self->request('get', @_));
}

sub post {
    my $self = shift;
    return($self->request('post', @_));
}

sub head {
    my $self = shift;
    return($self->request('head', @_));
}

sub logResponse {
    my $self = shift;
    my $msg = shift;
    my $resp = shift;
    my $level = shift || 30;
    
    $self->{'log'}->msg("$msg:\n" .
                        "Status Line: " .  $resp->status_line() .
                        "\nHeaders:\n" . $resp->headers()->as_string() .
                        "\nCookie:\n" . $self->{'lwp'}->cookie_jar()->as_string() .
                        "\nContent:\n" . $resp->content(), $level);
}

sub lastResponse {return($_[0]->{'last_resp'});}
sub stats {return($_[0]->{'stats'});}

1;
