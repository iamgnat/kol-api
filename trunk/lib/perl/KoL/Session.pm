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
use KoL;
use KoL::Logging;

sub new {
    my $class = shift;
    my %args = @_;
    my $kol = KoL->new();
    
    # Defaults.
    $args{'agent'} = 'KoLAPI/' . $kol->version() if (!exists($args{'agent'}));
    $args{'timeout'} = 60 if (!exists($args{'timeout'}));
    if (!exists($args{'server'})) {
        my $servers = $kol->hosts();
        my $i = int(rand(@{$servers}));
        $args{'server'} = $servers->[$i];
    }
    
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
        }
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

sub loggedIn {
    my $self = shift;
    
    return(0) if (!$self->{'sessionid'});
    return(1);
}

sub login {
    my $self = shift;
    my $user = shift;
    my $pass = shift;
    
    return(1) if ($self->{'sessionid'});
    
    if (!$pass) {
        if (!-t) {
            $@ = "No password supplied for '$user' and this is not an " .
                    "interactive terminal.";
            return(0);
        }
        $pass = KoL::promptUser("Enter password for '$user':", 'password');
        if (!$pass) {
            $@ = "Unable to get password from user: $@";
            return(0);
        }
    }
    
    my ($resp);
    $self->{'log'}->msg("Logging in as '$user'...", 10);
    
    # Get the hash key for hashing the password.
    #   Disable redirects so we can get the key.
    $self->{'log'}->msg("Getting hash key.", 10);
    $resp = $self->get('login.php');
    return (0) if (!$resp);
    
    # Did we redirect?
    if (!$resp->previous()) {
        $self->logResponse("Login page did not redirect", $resp);
        $@ = "Login page did not redirect: " . $resp->status_line();
        return(0);
    }
    
    # Did we get the login page?
    if ($resp->content() !~ m/Enter the Kingdom/s) {
        $self->logResponse("Did not get the login page", $resp);
        $@ = "Did not get the login page: " . $resp->status_line();
        return(0);
    }
    
    # Get the new URI.
    if ($resp->previous()->header('Location') !~ m/(login\.php\?loginid=\S+)/s) {
        $self->logResponse("Unable to get login URI", $resp);
        $@ = "Unable to get login URI: " . $resp->status_line();
        return(0);
    }
    my $loginURI = $1;
    
    # Get the challenge hash key
    if ($resp->content() !~ m/<input.+?name=["']*challenge["']*.+?value=["']*([^"'\s>]+)["'\s>]/s) {
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
    return(0) if (!$resp);
    
    if ($resp->content() =~ m/Login failed/s) {
        $@ = "Bad username or password.";
        return(0);
    }
    
    if ($resp->content() =~ m/Too many login attempts/s) {
        $@ = "Too many recent login attempts.";
        return(0);
    }
        
    $self->{'log'}->msg("Login request successful, processing results.", 10);
    my $cookies = $self->{'lwp'}->cookie_jar()->as_string();
    $self->{'log'}->msg("Cookies:\n$cookies", 30);
    if ($cookies !~ m/.*PHPSESSID\=(\w*).*/s) {
        $self->logResponse("Unable to locate session id after login as '$user'", $resp);
        $@ = "Unable to locate session id.";
        return(0);
    }
    
    $self->{'sessionid'} = $1;
    $self->{'user'} = $user;
    
    $resp = $self->get('charpane.php');
    return(0) if (!$resp);
    
    if ($resp->content() !~ m/var pwdhash = "(.+?)"/s) {
        $self->logResponse("Unable to locate pwdhash", $resp);
        $@ = "Unable to locate pwdhash!";
        return(0);
    }
    $self->{'pwdhash'} = $1;
    
    $self->{'kol'}->makeDirty();
    
    return(1);
}

sub logout {
    my $self = shift;
    
    return(1) if (!$self->{'sessionid'});
    
    my $resp = $self->get('logout.php');
    if (!$resp && $@ !~ m/Nightly Maintenance/is) {
        $@ = "Unable to logout '" . $self->{'user'} . "': $@";
        return(0);
    }
    
    $self->{'kol'}->makeDirty();
    
    my $user = $self->{'user'};
    $self->{'sessionid'} = undef;
    $self->{'user'} = undef;
    
    if (!$resp) {
        $self->{'log'}->debug("Logout due to system maintenance.");
        return(1);
    }
    
    if ($resp->content() !~ m/Logged Out/s) {
        $self->{'log'}->error("'$user' may not have been logged out as expected!");
        $self->logResponse("Unable to locate session id after login as '$user'", $resp);
    }
    return(1);
}

sub _processResponse {
    my $self = shift;
    my $resp = shift;
    
    # Simple record keeping to cut down on DoS like usage.
    if ($self->{'no_dos'}{'second'} != time()) {
        $self->{'no_dos'}{'second'} = time();
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
        if ($hdrs->{'location'} !~ m%http://([^/]+)/%s) {
            $self->{'log'}->debug("We were redirected, but can't process '" .
                                    $hdrs->{'location'} . "'.");
            return($resp);
        }
        $self->{'server'} = $1 if ($1 ne $self->{'server'});
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
    sleep(1) if (time() - $self->{'no_dos'}{'second'} < 1 &&
                    $self->{'no_dos'}{'count'} >= 30);
    
    my $url = 'http://' . $self->{'server'} . "/$uri";
    $self->{'log'}->msg("'$type' request for '$url'.", 10);
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

1;
