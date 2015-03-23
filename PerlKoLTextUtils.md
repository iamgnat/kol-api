

# Introduction #

This module doesn't have anything to do with [KoL](http://www.kingdomofloathing.com) itself. It is a generic object of text manipulation utilities.

## Methods ##
### new() ###
This is the constructor of the object.

It attempts to load the [Text::Wrap](http://search.cpan.org/~muir/Text-Tabs+Wrap-2009.0305/lib/Text/Wrap.pm) module if it is installed. If it is not, then it disables usage of that module.

It also attempts to load [Term::ReadKey](http://search.cpan.org/~jstowe/TermReadKey-2.30/ReadKey.pm) and determine the terminal width for purposes of wrapping text. If it is unable to determine the terminal width ([Term::ReadKey](http://search.cpan.org/~jstowe/TermReadKey-2.30/ReadKey.pm) not installed or the session is not a terminal), it disables wrapping text.

**Example:**
```
my $text = KoL::TextUtils->new();
```

### columns() ###
Returns the current number of columns being used for wrapping text. A result of 0 means that text will not be wrapped.

**Example:**
```
my $cols = $text->columns();
# ...
```

### setColumns($val) ###
Changes the value for _columns()_ to allow you to override the determined value. If _$val_ is 0, text wrapping will be disabled.

**Example:**
```
$text->setColumns(80);
```

### wrap($iPad, $sPad, $text) ###
This method takes the _$text_ string and attempts to wrap it using [Text::Wrap::wrap](http://search.cpan.org/~muir/Text-Tabs+Wrap-2009.0305/lib/Text/Wrap.pm). If _new()_ was unable to load [Text::Wrap](http://search.cpan.org/~muir/Text-Tabs+Wrap-2009.0305/lib/Text/Wrap.pm) or _columns()_ is set to 0, then _$text_ is returned with no modification.

The _$iPad_ is a string of characters you would like prepended to _$text_.

_$sPad_ is a string of characters you would like appended after each new line that is inserted.

For example if you wanted to format a long string into an English style paragraph, _$iPad_ could be four spaces (`'    '`) or a TAB ("\t") depending on your preference and _$sPad_ would be an empty string (''). If, instead, you were outputing something like a log message and wanted each wrapped line to be indented for readability, you might set _$iPad_ to an empty string ('') and _$sPad_ to some whitespace (e.g. `'    '`).

See _Text::Wrap_ for more details on how the actual wrapping is performed.

**Example:**

```
$text->setColumns(10);
print $text->wrap('', '    ', "This is a string of text that should wrap at least once.\n");
```