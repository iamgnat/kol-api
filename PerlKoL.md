

# Introduction #

This is the main module for the [KoLAPI](KoLAPI.md). It's purpose is to hold configuration and status information that is general to the API in general.

The end user of [KoLAPI](KoLAPI.md) should not need to directly use this module.

# Exported Functions #

These functions are not directly connected to the [KoL](PerlKoL.md) object.

### calledFrom($levels) ###
This function generates a string representation of the calling function/method a number of levels back as specified by the _$levels_ value. The _$levels_ default value is 2 if not specified which is the caller of the function calling _calledFrom()_.

**Example return value:**

`main(main::testLogging)`

### promptUser($msg, $type, $default) ###
This function interacts with the user via the TTY interface. It prompts the user with the _$prompt_ value, then verifies the supplied value against the _$type_ specified. If the response does not match the type, it will re-prompt them. If they supply no value (e.g. press enter) and a _$default_ value is supplied, the _$default_ value is returned. If there is an error, it returns _undef_ and sets _$@_.

**_$type_ values**:
| **value** | **regex** | **Notes** |
|:----------|:----------|:----------|
| bool | `^[01YyTtNnFf]` | Boolean values |
| boolean |  | See bool |
| int | `^-{0,1}\d+$` | Numeric (no decimals) values |
| integer |  | See int |
| num |  | See int |
| number |  | See int |
| string | `.*` | String value (including empty string) |
| password | `.*` | Same as string, except that it turns echo off on the TTY when getting the answer from the user. |

**Examples:**
```
print promptUser("Give me a int value:", 'int') . "\n";
print promptUser("Give me a bool value:", 'bool', 0) . "\n";
print promptUser("Give me a string value:", 'string', "you didn't give me a string") . "\n";
print promptUser("Give me a password value:", 'password') . "\n";
```

# Object #
The [KoL object](PerlKoL.md) is meant to be used by other modules and not directly by the API users. It's purpose is to contain and manage configuration information that is common to all of the KoL project. Such things as servers to use, the API version, etc..

The [KoL object](PerlKoL.md) is a singleton object so all calls will use the same instance. The reason for this is to facilitate communicating "system"-wide changes to all users of the object.

## Methods ##
### new() ###
This is the constructor of the object. If the singleton instance has not been created, it creates it. Once created (or if it already exists), it returns the singleton instance reference.

There are currently no arguments to this method.

**Example:**
```
my $kol = KoL->new();
```

### cli() ###
This method returns the global [KoL::CommandLine](PerlKoLCommandLine.md) object that should be used for parsing command line arguments. Other objects (e.g. [KoL::Session](PerlKoLSession.md)) will use this instance for getting information from the command line.

This argument takes no arguments.

**Example:**
```
my $cli = $kol->cli();
```

### setKoLHost($host) ###
This method allows you to change the host that is used to talk to Kingdom of Loathing.

The argument is the new host name to use.

**Example:**
```
$kol->setKoLHost('www.kingdomofloathing.com');
```

### host() ###
This method returns the host name to use for connecting to the Kingdom of Loathing server.

There are no arguments for this method.

**Method Example:**
```
my $hosts = $kol->host();
```

### version() ###
This method returns the version of the KoL API.

There are no arguments for this method.

**Method Example:**
```
my $kolVer = $kol->version();
```