**WARNING:**

This module is currently under active development. This means that:

  1. The API is not complete and functionality is being added and changed as it is developed.
  1. The documentation is likely not up to date with the code.

Using any functionality of this module at this time is just silly and at your own risk.

You've been warned!



# Introduction #

This deals with gather information from the [KoL Wiki](http://kol.coldfront.net/thekolwiki/index.php).

## TODO ##

This module is rudimentary at best. May want to get more details from the Wiki rather than from KoL to reduce hits to KoL. Don't know. Just thinking...

## Methods ##
### new(%args) ###
This is the constructor of the object.

The argument is a hash that can contain the following information:

| **Key** | **Required** | **Description** |
|:--------|:-------------|:----------------|
| agent | No | The agent string to use for HTTP requests. The default is "KoLAPI/" . [KoL->version()](PerlKoL#version().md). |
| timeout | No | The number of seconds to wait for a response. The default is 60. |
| server | No | The [KoL Wiki](http://kol.coldfront.net/thekolwiki/index.php) server to connect to. The default is 'kol.coldfront.net'. |
| email | Yes | An email address to include in the headers sent to the [KoL Wiki](http://kol.coldfront.net/thekolwiki/index.php). This should be the end user's email address. |

**Example:**

```
my $wiki = KoL::Wiki->new('email' => 'my@email.com', 'timeout' => 30);
```

### getItemIds($name) ###
This method request the [Wiki](http://kol.coldfront.net/thekolwiki/index.php) page for the given item and returns a hash reference of IDs it obtains from the page.

In the even of an error, it returns _undef_ and sets _$@_.

**Example:**

```
my $info = $wiki->getPage('Hot wad');
my $details = $inv->itemInfo($info->{'desc'});
# ...
```

### _processResponse($resp) ###
This should never be called directly by a bot builder or module developer. This is a "private" method for [KoL::Wiki](PerlKoLWiki.md) that is used by the_get()_,_head()_, and_post()_methods to process the HTTP response. It is only documented here to show the common error responses that it checks for and simplifies._

As well as detecting standard errors, it also takes care of respecting [KoL's](http://www.kingdomofloathing.com) request to use another server for future requests. If this occurs, it updates it's internal server name (set in _new()_).

When it detects an error, it returns _undef_ and sets $@ which is then passed on by the methods mentioned previously. The common errors it returns are:

  * KoL is down for Nightly Maintenance.

### get($uri, $form) ###
### head($uri, $form) ###
### post($uri, $form) ###
Each of these methods performs their named type of HTTP request and returns the _LWP::UserAgent_ result. If an error was detected (see processResponse()_), the result will be_undef_and $@ is set to an appropriate error message._

These methods are meant to be internal to the [KoL::Wiki](PerlKoLWiki.md) object rather than for external use like their [KoL::Session](PerlKoLSession.md) counterparts.

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
my $resp = $wiki->get(...);
if ($resp->content() !~ m/What I was expecting/) {
    $sess->logResponse("I didn't get what I expected", $resp);
    $@ = "Bad result!";
    return(0);
}
```