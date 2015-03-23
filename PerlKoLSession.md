

# Introduction #

This is the primary module for interacting with [KoL](http://www.kingdomofloathing.com).

This module is responsible for abstracting the communication with the [KoL](http://www.kingdomofloathing.com) server and managing the user's session information.

## Methods ##
### new(%args) ###
This is the constructor of the object.

The argument is a hash that can contain the following information:

| **Key** | **Required** | **Description** |
|:--------|:-------------|:----------------|
| agent | No | The agent string to use for HTTP requests. The default is "KoLAPI/" . [KoL->version()](PerlKoL#version().md). |
| timeout | No | The number of seconds to wait for a response. The default is 60. |
| server | No | The [KoL](http://www.kingdomofloathing.com) server to connect to. The default is the value of [KoL->host()](PerlKoL#hosts().md). |
| email | Yes | An email address to include in the headers sent to [KoL](http://www.kingdomofloathing.com). This should be the end user's email address. |

**Example:**

```
my $sess = KoL::Session->new('email' => 'my@email.com', 'timeout' => 30);
```

### dirty() ###
The _dirty()_, _makeDirty()_, and _time()_ methods provide modules a way to notify each other that they should update any cached information as a change has been made. These methods use _Time::HiRes_ for their time representations for more accurate checks.

The _dirty()_ method returns the last time that the _makeDirty()_ was called. Modules can use this result against their own saved UTC time to know if their last cache was before or after a known change to the character/environment information.

There are no arguments for this method.

**Example:**
```
if ($sess->dirty() > $myCachetime) {
    # Update cached information
}
# ...
```

### makeDirty() ###
The _dirty()_, _makeDirty()_, and _time()_ methods provide modules a way to notify each other that they should update any cached information as a change has been made. These methods use _Time::HiRes_ for their time representations for more accurate checks.

The _makeDirty()_ method sets a value in the object to the current time. This value is then returned by a call to _dirty()_. Call this method when your module has made a change to the KoL environment (e.g. sold an item, changed familiars, etc..) to let the rest of the modules know that they should invalidate their cache and re-fetch their information.

There are no arguments for this method.

**Example:**
```
# Perform some action to change character information (e.g. sell an item)
$myCacheTime = $sess->time();
$sess->makeDirty();
```

### time() ###
The _dirty()_, _makeDirty()_, and _time()_ methods provide modules a way to notify each other that they should update any cached information as a change has been made. These methods use _Time::HiRes_ for their time representations for more accurate checks.

This is a utility method so you don't have to work with _Time::HiRes_ yourself if you don't want to. Simply call this to get the current time that is compatible with checking against _dirty()_ to see if something has changed since your last check.

There are no arguments for this method.

**Example:**
```
# Perform some action to change character information (e.g. sell an item)
$myCacheTime = $sess->time();
$sess->makeDirty();
```

### loggedIn() ###
Returns 1|0 if the session is currently logged in.

Note that this just refers to if the module believes it is logged in which could be at odds with what [KoL](http://www.kingdomofloathing.com) is true. The session could have expired or the system could be down for maintenance which would not be known until the next request is made.

**Example:**

```
if (!$sess->loggedIn()) {
    if (!$sess->login(...)) {
        # Couldn't log in!
    }
}
```

### sessionID() ###
Returns the cookie session ID that was retrieved during login.

**Example:**

```
my $sessid = $sess->sessionID();
```

### pwdhash() ###
Returns the pwdhash value taken from charpane.php (in the JavaScript). This value is used in a few places throughout the system when submitting form data.

**Example:**

```
my $pwdhash = $sess->pwdhash();
```

### user() ###
Returns the username that was supplied to _login()_ during the login process.

**Example:**

```
my $user = $sess->user();
```

### login($user, $pass) ###
Attempts to login to [KoL](http://www.kingdomofloathing.com) using the provided credentials.

The _$user_ argument is required, but _$pass_ is not. If _$pass_ is not supplied, _login()_ will prompt the user for a password using [promptUser()](PerlKoL#promptUser($msg,_$type,_$default).md).

The method returns 0|1 to show if the attempt succeeded or not. If the login attempt fails, _$@_ is set with a relevant error message.

Upon a successful login, it calls [KoL::makeDirty()](PerlKol#makeDirty().md) to make sure subsequent requests re-fetch their data.

**Example:**

```
if (!$sess->login($user, $pass)) {
    $log->error("Unable to login as '$user': $@");
    exit(1);
}
```

### logout() ###
If the [session](PerlKoLSession.md) instance is currently logged in, it attempts to logout.

If the response to the logout request is that the system is down for maintenance, it treats this as a successful logout. If any other error occurs, the result is 0 and _$@_ is set.

**Example:**

```
if (!$sess->logout()) {
    $log->error("Unable to logout: $@");
    exit(1);
}
```

### _processResponse($resp) ###
This should never be called directly by a bot builder or module developer. This is a "private" method for [KoL::Session](PerlKoLSession.md) that is used by the_get()_,_head()_, and_post()_methods to process the HTTP response. It is only documented here to show the common error responses that it checks for and simplifies._

As well as detecting standard errors, it also takes care of respecting [KoL's](http://www.kingdomofloathing.com) request to use another server for future requests. If this occurs, it updates it's internal server name (set in _new()_).

When it detects an error, it returns _undef_ and sets $@ which is then passed on by the methods mentioned previously. The common errors it returns are:

  * KoL is down for Nightly Maintenance.

### get($uri, $form) ###
### head($uri, $form) ###
### post($uri, $form) ###
Each of these methods performs their named type of HTTP request and returns the _LWP::UserAgent_ result. If an error was detected (see processResponse()_), the result will be_undef_and $@ is set to an appropriate error message._

The _$uri_ value should just be the path you are requesting without the server information (e.g. 'charpane.php' vs. 'http://www3.kingdomofloathing.com/charpane.php'). The method will take care of adding the correct server information to the request for you.

The _$form_ argument is optional, but if specified should be a hash reference. The keys should be the form field names. In the case of _get()_ and _head()_ the hash are translated in to a URLEncoded query string. For a _post()_ request, the hash reference is simply passed to _LWP_ intact.

**Examples:**

```
my $resp = $sess->head('login.php');
```

```
my $resp = $sess->get('desc_item.php', {'whichitem' => 25});
```

```
my $resp = $sess->post($loginURI, {
    'loggingin' => 'Yup.',
    'loginname' => $user,
    'password'  => '',
    'challenge' => $hashKey,
    'secure'    => 1,
    'response'  => $pass
});
if (!$resp) {
    $log->error("Unable to complete post request: $@");
}
```

### logResponse($msg, $resp, $level) ###
This is a helper method to format some of the useful information from a response and print it using [PerlKoLLogging::msg($msg,_$level) KoL::Logging->msg()]._

The resulting message will be in the format:
```
_$msg_:
Status Line: $resp->status_line()
Headers:
$resp->headers()->as_string()

Cookie:
$self->{'lwp'}->cookie_jar()->as_string()

Content:
$resp->content()
```

If not specified _$level_ defaults to 30. See [KoL::Logging->msg()](PerlKoLLogging#msg($msg,_$level).md) for details about verbosity levels.

**Example:**

```
my $resp = $sess->get(...);
if ($resp->content() !~ m/What I was expecting/) {
    $sess->logResponse("I didn't get what I expected", $resp);
    $@ = "Bad result!";
    return(0);
}
```

### lastResp() ###
This method returns the last _HTTP::Response_ result for the last request that was made. This is to allow you to do potential further processing on request results that may not have been done by the object/method that made the request.

If no request has been made yet (e.g. before you login), undef is returned.

**Example:**
```
my $resp = $sess->lastResp();
if ($resp->content =~ m/Something i'm looking for/) {
    # ...
}
```

### stats() ###
Returns a [KoL::Stats](PerlKoLStats.md) instance bound to this session. If you haven't called _login()_ or have already called _logout()_, _undef_ will be returned.

**Example:**
```
my $stats = $sess->stats()
```