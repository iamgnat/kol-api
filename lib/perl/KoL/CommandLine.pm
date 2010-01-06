# $Id$

# CommandLine.pm
#   Class for processing command line arguments.

package KoL::CommandLine;

use strict;
use POSIX;
use KoL;
use KoL::FileUtils;
use KoL::TextUtils;
use KoL::Logging;

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = {
        'args'          => {},
        'unclaimed'     => [], # Args that did not get bound to an option.
        'ignored'       => [], # Args that appears after the -- end of args delimiter.
        'name-length'   => 0,
        'log'           => undef,
        'text'          => undef,
    };
    
    bless($self, $class);
    
    if (exists($args{'log'})) {
        $self->{'log'} = $args{'log'};
    } else {
        $self->{'log'} = KoL::Logging->new(%args, 'cli', $self);
    }
    
    if (exists($args{'text'})) {
        $self->{'text'} = $args{'text'};
    } else {
        $self->{'text'} = KoL::TextUtils->new();
    }
    
    return($self);
}

# Definition of 'info' hash to configure the option:
# %info = (
#   name        = Required. The name of the option ([A-Za-z0-9_-]+).
#   type        = Required. The type of option value (number, boolean, string).
#   multiple    = Optional. Can the option be specified multiple times (0|1).
#                   If true, the value after processing will be an array
#                   reference of the supplied values.
#   short-name  = Optional. A single character option name.
#   description = Optional. A description of the option's purpose. If not
#                   supplied, the option will not be displayed when
#                   printHelp() is called.
#   required    = Optional. If true and the option is not supplied, issues
#                   an error message and stops execution.
#   default     = Optional. The default value to use if the option was not
#                   supplied.
#   allowed     = Optional. An array reference of allowed values for the
#                   option. If a value is supplied that is not in the list,
#                   processing is halted with an appropriate error message.
#   callback    = Optional. A callback function/method to run after all
#                   options have been processed. This may take two formats.
#                   The first is a simple code refernce to the function that
#                   will be called. The second is an array reference with the
#                   first element as the instantiated object and the second
#                   the reference to the method.
#                   When called (either format), the following arguments are
#                   supplied:
#                       cli     - The CommandLine object.
#                       name    - The name of the option.
#                       value   - The value of the option.
#                   The callback WILL NOT be called for options that were
#                   not supplied and do not have a default value. If the
#                   option is not supplied and it does have a default
#                   value, the callback WILL be called.
# )
#
sub addOption {
    my $self = shift;
    my %info = @_;
    my $log = $self->{'log'};
    
    if (!exists($info{'name'}) || !exists($info{'type'})) {
        $log->error("Invalid option specification at " . calledFrom() .
                    ": Missing 'name' and/or 'type' definition.");
        exit(1);
    }
    
    # Check the argument type to make sure it is supported.
    if ($info{'type'} =~ m/^(i|int|integer|d|dec|decimal|n|num|number)$/) {
        $info{'type'} = 'number';
        $info{'type-pat'} = '^-{0,1}\d+$';
    } elsif ($info{'type'} =~ m/^(b|bool|boolean)$/) {
        $info{'type'} = 'boolean';
        $info{'type-pat'} = '^([tfyn10]|yes|no|true|false)$';
    } elsif ($info{'type'} =~ m/^(s|str|string)$/) {
        $info{'type'} = 'string';
        $info{'type-pat'} = '^.+$';
    } else {
        $log->error("Invalid option specification at " . calledFrom() .
                    ": Unknown type '" . $info{'type'} . "'.");
        exit(1);
    }
    
    # Validate the name(s).
    if (exists($self->{'args'}{$info{'name'}})) {
        $log->error("Invalid option specification at " . calledFrom() .
                    ": The name value '" . $info{'name'} . "' is already in use.");
        exit(1);
    }
    if ($info{'name'} !~ m/^[a-z0-9][a-z0-9_-]+$/i) {
        $log->error("Invalid option specification at " . calledFrom() .
                    ": The name value '" . $info{'name'} . "' contains invalid characters.");
        exit(1);
    }
    if ($info{'name'} =~ m/^no-/) {
        $log->error("Invalid option specification at " . calledFrom() .
                    ": The name may not start with 'no-'.");
        exit(1);
    }
    if (exists($info{'short-name'}) && (length($info{'short-name'}) != 1 ||
        $info{'short-name'} !~ m/[a-z0-9]/i)) {
        $log->error("Invalid option specification at " . calledFrom() .
                    ": The short-name '" . $info{'short-name'} . "' is an incorrect " .
                    "length or contains illegal characters.");
        exit(1);
    }
    if (exists($info{'short-name'}) && exists($self->{'args'}{$info{'short-name'}})) {
        $log->error("Invalid option specification at " . calledFrom() . 
                    ": The short-name '" . $info{'short-name'} . "' is already in use.");
        exit(1);
    }
    
    # Configure if we process multiple of the same option.
    if (exists($info{'multiple'}) && $info{'multiple'} =~ m/^([ty1]|yes|true)$/i) {
        $info{'multiple'} = 1;
    } else {
        $info{'multiple'} = 0;
    }
    
    # Validate their default value if given.
    if (exists($info{'default'}) && $info{'default'} !~ m/$info{'type-pat'}/i) {
        $log->error("Invalid option specification at " . calledFrom() . 
                    ": The default value '" . $info{'short-name'} . "' is not of type " .
                    $info{'type'} . ".");
        exit(1);
    }
    
    # Validate their allowed values if given.
    if (exists($info{'allowed'})) {
        if (ref($info{'allowed'}) ne 'ARRAY') {
            $log->error("Invalid option specification at " . calledFrom() . 
                        ": The allowed value is not an Array reference.");
            exit(1);
        }
        
        foreach my $el (@{$info{'allowed'}}) {
            if ($el !~ m/$info{'type-pat'}/) {
                $log->error("Invalid option specification at " . calledFrom() . 
                            ": The allowed value '$el' is not of type " .
                            $info{'type'} . ".");
                exit(1);
            }
        }
    }
    
    # Validate the handler if given.
    if (exists($info{'callback'})) {
        my $func = ref($info{'callback'}) eq 'ARRAY' ?
                    $info{'callback'}->[1] : $info{'callback'};
        if (ref($func) ne 'CODE') {
            $log->error("Invalid option specification at " . calledFrom() . 
                        ": The callback is not a code reference.");
            exit(1);
        }
    }
    
    # Create the basic hash.
    my %arg = (
        'name'      => $info{'name'},
        'type'      => $info{'type'},
        'type-pat'  => $info{'type-pat'},
        'multiple'  => $info{'multiple'}
    );
    
    # Add the option elements
    $arg{'short-name'} = $info{'short-name'} if (exists($info{'short-name'}));
    $arg{'description'} = $info{'description'} if (exists($info{'description'}));
    $arg{'default'} = $info{'default'} if (exists($info{'default'}));
    $arg{'allowed'} = $info{'allowed'} if (exists($info{'allowed'}));
    $arg{'callback'} = $info{'callback'} if (exists($info{'callback'}));
    $arg{'required'} = ($info{'required'} =~ m/^[yt1]/i ? 1 : 0) if (exists($info{'required'}));
    
    # Save it in the args list and update the max name length.
    $self->{'args'}{$info{'name'}} = \%arg;
    $self->{'args'}{$info{'short-name'}} = \%arg if (exists($info{'short-name'}));
    $self->{'name-length'} = length($info{'name'})
        if (length($info{'name'}) > $self->{'name-length'});
    
    return;
}

sub process {
    my $self = shift;
    my $args = shift || \@ARGV;
    my $log = $self->{'log'};
    
    $log->debug("Processing: " . join(' ', @{$args}));
    
    my (@unclaimed, @ignored);
    
    # Process the arguments.
    for (my $i = 0 ; $i < @{$args} ; $i++) {
        my $arg = $args->[$i];
        
        $log->debug("Processing '$arg'");
        
        if ($arg eq '--') {
            # End of args to process.
            $log->debug("  Remaining args are ignored.");
            for (my $j = $i + 1 ; $j < @{$args} ; $j++) {
                push(@ignored, $args->[$j]);
            }
            last;
        }
        
        if ($arg !~ m/^-/) {
            # It's an unclaimed arg.
            $log->debug('  Unclaimed.');
            push(@unclaimed, $arg);
            next;
        }
        
        $arg =~ s/^-+//;
        my $name = $arg;
        $name =~ s/^no-//;
        $log->debug("  Name is '$name'");
        my ($value);
        
        if (!exists($self->{'args'}{$name})) {
            $self->printHelp("'$name' is an unknown option.");
            exit(1);
        }
        
        my $info = $self->{'args'}{$name};
        
        # Get the value
        if ($info->{'type'} ne 'boolean' && $arg =~ m/^no-/) {
            $self->printHelp("'$name' is not a boolean option, therefore the 'no-' " .
                                "prefix is not valid.");
            exit(1);
        } elsif ($info->{'type'} eq 'boolean') {
            # Boolean option.
            $value = ($arg =~ m/^no-/) ? 0 : 1;
            $log->debug("  Boolean value of '$value'");
        } else {
            # Everything else.
            my $x = $i + 1;
            
            # Deal with a number being the last option with no value
            #   or the number option apparently not having a valid value as
            #   the next argument (e.g. '-v -v').
            #   The caveat is that if the next argument was supposed to be
            #   a negative value but it doesn't match the type pattern (e.g. typo),
            #   then it will be treated as the next option. This will either
            #   (hopefully) erronously report it as a bad option or (worse)
            #   process it as a valid option and corrupt the placement of
            #   the rest of the arguments.
            if ($info->{'type'} eq 'number' && ($x >= @{$args} ||
                ($args->[$x] =~ m/^-/ && $args->[$x] !~ m/$info->{'type-pat'}/i))) {
                $value = 1;
            } else {
                $value = $args->[$x];
                $i++;
            }
            $log->debug("  Value of '$value'");
        }
        
        # Did we get a value?
        if (!defined($value)) {
            $self->printHelp("No option value specified for '$name'.");
            exit(1);
        }
        
        # Is it the correct type?
        if ($value !~ m/$info->{'type-pat'}/i) {
            $self->printHelp("Invalid value given for '$name' option. It is not of type " .
                                $info->{'type'});
            exit(1);
        }
        
        # Is it allowed?
        if (exists($info->{'allowed'})) {
            $log->debug("  Processing allowed values.");
            my $check = 0;
            foreach my $val (@{$info->{'allowed'}}) {
                $log->debug("    '$val' eq '$value'?");
                if ($val eq $value) {
                    $check = 1;
                    last;
                }
            }
            if (!$check) {
                $self->printHelp("Invalid value given for '$name' option. It is not an " .
                                    "allowed value.");
                exit(1);
            }
        }
        
        # Store the value.
        if (!exists($info->{'multiple'}) || !$info->{'multiple'}) {
            if ($info->{'type'} eq 'number' && exists($info->{'value'})) {
                # If it's number and not saving multiple values, add them
                #   together. (e.g. for raising the verbosity based on the
                #   number of -v options)
                $value += $info->{'value'};
            }
            $info->{'value'} = $value;
        } else {
            $info->{'value'} = [] if (!exists($info->{'value'}));
            push(@{$info->{'value'}}, $value);
        }
    }
    
    # They asked for help.
    if ($self->getValue('help')) {
        $self->printHelp();
        exit(0);
    }
    
    # Post process.
    $log->debug("Post processing options.");
    foreach my $arg (keys(%{$self->{'args'}})) {
        next if (length($arg) == 1); # Short name
        my $info = $self->{'args'}{$arg};
        
        $log->debug("  '$arg'");
        
        # Set the default value if needed.
        if (exists($info->{'default'}) && !exists($info->{'value'})) {
            $log->debug('    Setting default value.');
            $info->{'value'} = $info->{'default'};
        }
        
        # If it's required, make sure we got a value.
        #   Note: Done before default to stay true to it's intent of
        #           requiring something from the input source.
        if (exists($info->{'required'}) && $info->{'required'} &&
            !exists($info->{'value'})) {
            $self->printHelp("The option '$arg' was not supplied, but it is required.");
            exit(1);
        }
        
        # Execute the callback handler.
        if (exists($info->{'callback'})) {
            my $func = $info->{'callback'};
            if (ref($func) eq 'CODE') {
                $log->debug('    Executing callback function.');
                # Simple function.
                &{$func}($self, $info->{'name'}, $info->{'value'});
            } else {
                $log->debug('    Executing callback method.');
                # Object method.
                my $obj = $func->[0];
                $func = $func->[1];
                $obj->$func($self, $info->{'name'}, $info->{'value'});
            }
        }
        
    }
    
    $self->{'unclaimed'} = \@unclaimed;
    $self->{'ignored'} = \@ignored;
    
    return;
}

sub unclaimed {
    my $self = shift;
    my $idx = shift;
    
    $idx -= 1 if (defined($idx));
    
    return(@{$self->{'unclaimed'}})
        if (!defined($idx) || $idx !~ m/^\d+$/ ||
            $idx > @{$self->{'unclaimed'}} - 1);
    return($self->{'unclaimed'}[$idx]);
}

sub ignored {
    my $self = shift;
    
    return(@{$self->{'ignored'}});
}

sub getValue {
    my $self = shift;
    my $arg = shift;
    
    if (exists($self->{'args'}{$arg})) {
        # Return the value if supplied.
        return($self->{'args'}{$arg}{'value'})
            if (exists($self->{'args'}{$arg}{'value'}));
        
        # Was not supplied, return the default value if any.
        return($self->{'args'}{$arg}{'default'})
            if (exists($self->{'args'}{$arg}{'default'}));
    }
    
    # Invalid arg or not supplied and no default.
    return(undef);
}

sub printHelp {
    my $self = shift;
    my $msg = shift;
    my $text = $self->{'text'};
    my $len1 = $self->{'name-length'};
    my $len2 = $len1 + 16;
    my $len3 = $len1 + 13;
    
    if (defined($msg)) {
        print STDERR $text->wrap('', '       ', "ERROR: $msg") . "\n";
    }
    
    print STDERR $text->wrap('', '    ', "$0 usage:") . "\n";
    
    # Print options with short names first.
    foreach my $arg (sort(keys(%{$self->{'args'}}))) {
        next if (length($arg) != 1); # Skip long names.
        
        my $info = $self->{'args'}{$arg};
        next if (!exists($info->{'description'})); # Skip args with no description.
        
        # Print the option and it's description.
        my $req = (exists($info->{'required'}) && $info->{'required'}) ? 'Required' : 'Optional';
        print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                    sprintf("    -$arg | --%-${len1}s - %s. %s",
                                            $info->{'name'}, $req, $info->{'description'})) . "\n";
        
        # Print the value type.
        print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                    sprintf("%${len3}s Type: %s",
                                            ' ', $info->{'type'})) . "\n";
        
        # Print the allowed values.
        if (exists($info->{'allowed'})) {
            print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                        sprintf("%${len3}s Allowed: %s",
                                                ' ', join(', ', @{$info->{'allowed'}}))) . "\n";
        }
        
        # Print the default value.
        if (exists($info->{'default'})) {
            print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                        sprintf("%${len3}s Default: %s",
                                                ' ', $info->{'default'})) . "\n";
        }
    }
    
    # Now print out the long names.
    foreach my $arg (sort(keys(%{$self->{'argList'}}))) {
        next if (length($arg) == 1); # Skip short names.
        
        my $info = $self->{'args'}{$arg};
        next if (exists($info->{'short-name'}));
        next if (!exists($info->{'description'})); # Skip args with no description.
        
        # Print the option and it's description.
        my $req = (exists($info->{'required'}) && $info->{'required'}) ? 'Required' : 'Optional';
        print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                    sprintf("         --%-${len1}s - %s. %s",
                                            $info->{'name'}, $req, $info->{'description'})) . "\n";
        
        # Print the value type.
        print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                    sprintf("%${len3}s Type: %s",
                                            ' ', $info->{'type'})) . "\n";
        
        # Print the allowed values.
        if (exists($info->{'allowed'})) {
            print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                        sprintf("%${len3}s Allowed: %s",
                                                ' ', join(', ', @{$info->{'allowed'}}))) . "\n";
        }
        
        # Print the default value.
        if (exists($self->{'default'})) {
            print STDERR $text->wrap('', sprintf("%${len2}s", ' '), 
                                        sprintf("%${len3}s Default: %s",
                                                ' ', $info->{'default'})) . "\n";
        }
    }
}

1;
