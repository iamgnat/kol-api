# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

# FileUtils
#   Utility functions for reading and writing files.

package KoL::FileUtils;

use strict;
use warnings;
use Symbol;

our(@ISA, @EXPORT);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(readFile writeFile appendFile);

sub readFile {
    my $file = shift;
    
    my ($fh);
    if (ref($file) eq 'GLOB') {
        # They passed us a (hopefully) readable filehandled (e.g. \*STDIN);
        $fh = $file;
    } else {
        $fh = Symbol::gensym();
    
        if (!open($fh, '<', $file)) {
            $@ = "Unable to open '$file' for reading: $!";
            return(wantarray() ? () : undef);
        }
    }
    
    my $data = do {local $/; <$fh>};
    
    if (ref($file) ne 'GLOB') {
        # We opened it, close it.
        if (!close($fh)) {
            $@ = "Unable to close '$file': $!";
            return(wantarray() ? () : undef);
        }
    }
    
    $@ = '';
    return(split(/\n/, $data)) if (wantarray());
    return($data);
}

sub writeFile {
    my $file = shift;
    my $data = shift;
    
    my ($fh);
    if (ref($file) eq 'GLOB') {
        # They passed us a (hopefully) writable filehandled (e.g. \*STDOUT);
        $fh = $file;
    } else {
        $fh = Symbol::gensym();
    
        if (!open($fh, '>', $file)) {
            $@ = "Unable to open '$file' for writing: $!";
            return(0);
        }
    }
    
    print $fh $data;
    
    if (ref($file) ne 'GLOB') {
        # We opened it, close it.
        if (!close($fh)) {
            $@ = "Unable to close '$file': $!";
            return(0);
        }
    }
    
    return(1);
}

sub appendFile {
    my $file = shift;
    my $data = shift;
    
    if (ref($file) eq 'GLOB') {
        # They passed us a (hopefully) writable filehandled (e.g. \*STDOUT);
        return(writeFile($file, $data));
    }
    my $fh = Symbol::gensym();
    
    if (!open($fh, '>>', $file)) {
        $@ = "Unable to open '$file' for appending: $!";
        return(0);
    }
    
    return(0) if (!writeFile($fh, $data));
    
    # We opened it, close it.
    if (!close($fh)) {
        $@ = "Unable to close '$file': $!";
        return(0);
    }
    
    return(1);
}

1;
