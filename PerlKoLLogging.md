

# Introduction #

This module doesn't have anything to do with [KoL](http://www.kingdomofloathing.com) itself. It is a generic object of logging utilities.

As this is meant to handle global logging functionality, this is a singleton object.

## Methods ##
### new(%args) ###
This is the constructor of the object. If the singleton instance has not been created, it creates it. Once created (or if it already exists), it returns the singleton instance reference.

The _%args_ is not required, but can take the following options:

| **Key** | **Default** | **More Info** |
|:--------|:------------|:--------------|
| debugHandles | `\*STDERR` | [setDebugHandles()](PerlKoLLogging#setDebugHandles($handles).md) |
| errorHandles | `\*STDERR` | [setErrorHandles()](PerlKoLLogging#setErrorHandles($handles).md) |
| msgHandles | `\*STDOUT` | [setMsgHandles()](PerlKoLLogging#setMsgHandles($handles).md) |
| date\_fmt | `%Y/%m/%d %H:%M:%S` | [setTimestampFormat()](PerlKoLLogging#setTimestampFormat($fmt).md) |
| debug | 0 | [setDebug()](PerlKoLLogging#setDebug($value).md) |
| verbosity | 1 | [setVerbosity()](PerlKoLLogging#setVerbosity($value).md) |
| pad | 4 | [setWrapPad()](PerlKoLLogging#setWrapPad($value).md) |
| cli | undef | [setupCLI()](PerlKoLLogging#setupCLI($cli).md) |

**Example:**
```
my $log = KoL::Logging->new();
```

### setupCLI($cli) ###
This method is used to associate the object to an instance of [KoL::CommandLine](PerlKoLCommandLine.md). When called, it uses the [addOption()](PerlKoLCommandLine#addOption(%info).md) method to add the debug (-d, --debug) and verbosity (-v, --verbosity) options.

If this is called after it has already been associated to a [KoL::CommandLine](PerlKoLCommandLine.md) instance, it has no effect (on either object).

The _$cli_ argument should be a [KoL::CommandLine](PerlKoLCommandLine.md) instance.

This method is not intended to be called directly. It is called by either calling the _new()_ method with the _cli_ key in it's argument hash or by instantiating a [KoL::CommandLine](PerlKoLCommandLine.md) instance.

Because instantiating [KoL::CommandLine](PerlKoLCommandLine.md) with instigate calling _setupCLI()_ (either by calling it directly if you have passed the _log_ key in it's argument hash or by instantiating [KoL::Logging](PerlKoLLogging.md) and passing the _cli_ hash key), it is important that you pay attention to when your objects are instantiated if you intend to use more than one instance of [KoL::CommandLine](PerlKoLCommandLine.md). To be safe, make sure that the instance that will be processing _@ARGV_ is always instantiated first.

### optionCallback() ###
This method is not intended for external use. This is the method that is called when the debug and/or verbosity options are specified in the arguments being processed by [KoL::CommandLine](PerlKoLCommandLine.md).

### setDebugHandles($handles) ###
### setErrorHandles($handles) ###
### setMsgHandles($handles) ###
These methods allow you to change where log messages of the respective type (_debug()_, _error()_, _msg()_) are written.

The _$handles_ argument can be one of two formats. It can be a single _GLOB_ reference or it can be an array reference of _GLOB_ references.

The second form of the _$handles_ argument allows you to have a single call to write a log message to multiple places at once (e.g. STDOUT and a log file).

The supplied handles overwrite any existing handles. If other files handles were previously opened (e.g. log files), you are responsible for closing them.

If there is an error using a handle (e.g. it's not a _GLOB_ reference), a message is written to STDERR for the offending 'handle'. The error message attempts to give you as much detail as possible by using [KoL::calledFrom()](PerlKoL#calledFrom($level).md) to tell you were the offending handle came from.

If no suitable handles were given, an error is written to STDERR telling the user that logging for that log type (e.g. _debug()_, _error()_, _msg()_) has been disabled.

**Examples:**

```
# Send debug messages to STDOUT instead of STDERR
$log->setDebugHandles(\*STDOUT);
```

```
# Write error messages to a file and redirect to STDOUT instead of STDERR.
my $fh = Symbol::gensym();
# open your file for writing ...
$log->setErrorHandles([$fh, \*STDOUT]);
```

```
# Write normal messages to a file.
my $fh = Symbol::gensym();
# open your file for writing ...
$log->setMsgHandles([$fh]);
```

### setTimestampFormat($fmt) ###
Changes the format used for the time stamp that is prepended to each log message.

The _$fmt_ value should be a _strftime()_ compatible format.

**Example:**

```
$log->setTimestampFormat('%m/%d/%y %H:%M:%S');
```

### setDebug($value) ###
Enables/Disables calls to _debug()_ print it's messages.

The _$value_ value should be 1 to enable _debug()_ messages and 0 to disable them.

**Example:**

```
$log->setDebug(1);
```

### debugging() ###
Returns the current setting for _debug()_ messages being enabled.

**Example:**

```
if ($log->debugging()) {
    # do something...
}
```

### setVerbosity($value) ###
Sets the current level of verbosity that is used by _msg()_ to determine if a message should be written.

_$value_ should be a positive whole number. If _$value_ is not given or it is 0, it is defaulted to a value of 1. If _$value_ is not a number, the current verbosity is not changed.

**Example:**
```
$log->setVerbosity(30);
```

### verbosity() ###
Returns the current verbosity level.

**Example:**
```
if ($log->verbosity() > 20) {
    # do something ...
}
```

### setWrapPad($value) ###
Changes the indention width when log messages are line wrapped.

_$value_ should be a positive number that represents the number of spaces to prepend to each wrapped line. If not specified, it defaults to 0 (e.g. no padding). If _$value_ is not a number, the current pad setting is not changed.

**Example:**

```
$log->setWrapPad(2);
```

### debug($msg) ###
If debugging is currently enabled (_debugging()_), it writes the given _$msg_ to the file handles set using _setDebugHandles()_ (or the default of STDERR).

Prior to writing _$msg_ it prepends it with the following information:

  * The time stamp based on the _setTimeStampFormat()_ (default "%Y/%m/%d %H:%M:%S").
  * The string "DEBUG: ".
  * The results of [KoL::calledFrom()](PerlKoL#calledFrom($level).md).
  * The string ": "

**Example:**

```
$log->debug("This is my debug message.");
```

### error($msg) ###
Writes _$msg_ to the file handles set using _setErrorHandles()_ (default is STDERR).

It prepends _$msg_ with:

  * The time stamp based on the _setTimeStampFormat()_ (default "%Y/%m/%d %H:%M:%S").
  * The string "ERROR: ".

**Example:**

```
$log->error("This is my error message.");
```

### msg($msg, $level) ###
Writes _$msg_ to the file handles set using _setMsgHandles()_ (default is STDOUT).

If _$level_ is not supplied, it defaults to 1. Prior to writing _$msg_, it verifies that _$level_ is less than or equal to the current _verbosity()_ value.

Before writing _$msg_, it prepends it with the time stamp based on the _setTimeStampFormat()_ (default "%Y/%m/%d %H:%M:%S").

**Examples:**

```
$log->msg("A normal message that should always be printed.");
```

```
$log->msg("A message that should only be printed with a high verbosity.", 99);
```