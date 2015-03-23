

# Introduction #

This module is focused on simplifying the use of command line arguments. This module does not have any interaction with the [KoL](http://www.kingdomofloathing.com) servers.

By default it parses the global _@ARGV_ when processing arguments. You can, however, pass an array reference to the [process()](PerlKoLCommandLine#process($args).md) for it to process instead of _@ARGV_.

## Methods ##
### new(%args) ###
This is the constructor of the object. This creates a new command line object for you to use.

You may pass a hash as the only argument. The hash should contain options you want to set at the time the object is instantiated. The supported keys are:

| **Key** | **Value** | **Default** |
|:--------|:----------|:------------|
| log | [KoL::Logging](PerlKoLLogging.md) object | Creates it's own instance. |
| text | [KoL::TextUtils](PerlTextUtils.md) object | Creates it's own instance. |

**Examples:**
```
my $cli = KoL::CommandLine->new();
```
```
my $cli = KoL::CommandLine->new('log' => $log);
```

### addOption(%info) ###
Use this method to add additional options to look for when parsing the command line arguments.

The _%info_ hash controls the information about your option. The supported keys are:

| **Key** | **Required?** | **Purpose** |
|:--------|:--------------|:------------|
| allowed | No | An array reference of allowed values. |
| callback | No | A function to call after the arguments have been processed. See callback details below for more information. |
| default | No | A default value if the option is not given. |
| description | No | Test to display if -h/--help is supplied or [help()](PerlKoLCommandLine#help($msg).md) is called. If this option is not supplied, information about the option will not show up in the help output. |
| multiple | No | 1|0 Can this option be supplied more than once? See details of multiple option support below. |
| name | Yes | The name of the argument. The name may only contain alpha-numerics, dashes, and underscores. It must be at least 2 characters long and the first character must be an alpha-numeric. |
| required | No | 1|0 Is this option required? |
| short-name | No | An alternate single character option name. |
| type | Yes| The type of the option value. See below for a list supported types and their meaning. |

**Callback details:**

You can specify a callback handler to be called after the arguments have been processed. This handler will be called if either the option was specified in the arguments or you supplied a default value. The value of the _callback_ hash value can take two forms. The first is a simple reference to the function to be called. The second form is an array reference with two values and allows the callback to be to an instantiated method. The first value is the instantiated object and the second is the function reference.

It is important to note that the callback is executed after all the arguments are processed. This means that the if the option is specified more than once, the callback is only executed once with the final value.

When executed, your callback handler will receive the following arguments in this order:

  * The [KoL::CommandLine](PerlKoLCommandLine.md) object instance that is calling the function/method.
  * The name of the option triggering the callback.
  * The value of the option.

**Default vs. Required:**

If you supply a _default_ value for the option, the _required_ value is ignored.

Note that if you use the _allowed_ functionality, your _default_ value must be in the _allowed_ list or it will generate an error when the arguments are processed (assuming the option was not supplied in the argument list).

**Multiple Options:**

For options that have the _multiple_ option set to 1 will combine multiple instances of the option in the argument list into a single value. If the option does not have _multiple_ set to true, only the last supplied value is used (e.g. each instance overwrites the previous value).

The final value will come in one of two forms. If the _type_ is int, then the final value is a single value which is a sum of all the supplied values. Any other _type_ results in the final value being an array reference of all the supplied values.

The common usage of supplying multiple _short-name_ together (e.g. -vvvv = -v 4 or -v -v -v -v) is not currently supported.

**Naming info:**

Any reference to an option name refers to the longer _name_ value. The only place the _short-name_ is used is in the arguments.

At the command line the _name_ options are preceded by two dashes (e.g. --myopt) while _short-name_ is only preceded by a single dash (e.g. -m).

**Option Types:**

| **Name** | **regexp** | **Description** |
|:---------|:-----------|:----------------|
| bool | `^[01YyTtNnFf]` | Boolean values |
| boolean |  | See bool |
| int | `^-{0,1}\d+$` | Numeric (no decimals) values |
| integer |  | See int |
| num |  | See int |
| number |  | See int |
| string | `.*` | String value (including empty string) |

For boolean type arguments you may prepend "no-" to the _name_ in the argument list to negate the value (e.g. if --foo results in a true value, --no-foo results in a false value).

**Example:**

```
sub myCallback {
    my $cli = shift;
    my $name = shift;
    my $val = shift;
    print "$name = '$val'\n";
}

$cli->addOption(
    'name'          => 'my-opt',
    'short-name'    => 'm',
    'type'          => 'string',
    'default'       => 'foo bar',
    'callback'      => \&myCallback,
    'allowed'       => ['foo bar', 'foo', 'bar'],
    'description'   => 'My example option.'
);
```

### process($args) ###

This method causes the argument list to be processed. If not supplied, _$args_ defaults to _@ARGV_ from the command line. You may, instead, supply an array reference of arguments to be processed.

If there is an error, it prints an error message (using [KoL::Logging](PerlKoLLogging.md)) and exits with a return code of 1.

**Example:**

```
$cli->process();
```

### unclaimed($idx) ###
After calling the _process()_ method, you can call unclaimed to retrieve arguments that were not associated with an option.

If _$idx_ is not supplied or invalid, all the unclaimed options are returned as an array. If _$idx_ - 1 is a valid element in the unclaimed list, only that element is returned.

**Example:**

```
my @unc = $cli->unclaimed();
foreach my $unc (@unc) {
    # Do something with it...
}
```

### ignored() ###
This method returns a list of arguments that were supplied after a double-dash (e.g. '--') which tells _process()_ to stop processing the argument list. This functionality is useful if your program has sub-commands where you need to process general options first and then further option based on which sub-command it is.

The result of this method is an array of the remaining arguments after the double-dash.

**Example:**

```
$cli->process();
if ($cli->unclaimed(1) eq 'sub-command') {
    my @subArgs = $cli->ignored();
    my $subCli = KoL::CommandLine->new();
    $subCli->addOption(...);
    $subCli->addOption(...);
    $subCli->process(\@subArgs);
    #...
}
```

### getValue($name) ###
Returns the value supplied for the _$name_ option or undef.

**Example:**

```
my $myopt = $cli->getValue('myopt');
print "'$myopt' was supplied for --myopt.\n" if (defined($myopt));
```

### printHelp($msg) ###
This method prints out formated help text of the options to STDERR. The help text includes the description, the type of option, it's default value (if any), if it is required, and the list of allowed values (if any).

If given, the _$msg_ string will be printed prior to the help text in the format "ERROR: _$msg_".

If an option does was not supplied a _description_ element, the it will not show up in the help text.

**Example:**

```
my $myopt = $cli->getValue('myopt');
if ($myopt ne 'what i want') {
    $cli->printHelp("The --myopt value is incorrect.");
    exit(1);
}
```