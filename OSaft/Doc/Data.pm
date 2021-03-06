#!/usr/bin/perl
## PACKAGE {

#!# Copyright (c) 2021, Achim Hoffmann
#!# This software is licensed under GPLv2.  Please see o-saft.pl for details.

## no critic qw(Documentation::RequirePodSections)
#        Our POD below is fine, Perl::Critic (severity 2) is too pedantic here.

## no critic qw(RegularExpressions::ProhibitFixedStringMatches)
#        Using regex instead of strings is not bad.  Perl::Critic (severity 2)
#        is too pedantic here.

## no critic qw(ControlStructures::ProhibitPostfixControls)
#        We believe it's better readable (severity 2 only)

## no critic qw(RegularExpressions::RequireExtendedFormatting)
#        Most of our regex are easy to read, it's the nature of the code herein
#        to have simple and complex regex.  /x is used for human readability as
#        needed.

package OSaft::Doc::Data;

use strict;
use warnings;

BEGIN { # mainly required for testing ...
    # SEE Perl:BEGIN perlcritic
    my $_path = $0;     $_path =~ s#[/\\][^/\\]*$##;
    unshift(@INC, ".",  $_path);
}

our $VERSION    = "21.01.12";  # official verion number of tis file
my  $SID_data   = "@(#) Data.pm 1.41 21/01/14 00:18:58";

# binmode(...); # inherited from parent, SEE Perl:binmode()

use osaft qw(print_pod STR_WARN);

sub _warn   {
    my @txt = @_;
    return if (grep{/(?:--no.?warn)/} @ARGV);   # ugly hack
    local $\ = "\n";
    print(STR_WARN, join(" ", @txt));
    # TODO: in CGI mode warning must be avoided until HTTP header written
    return;
}; # _warn

#_____________________________________________________________________________
#_____________________________________________________ public documentation __|

=pod

=encoding utf8

=head1 NAME

OSaft::Doc::Data - common Perl module to read data for user documentation

=head1 SYNOPSIS

=over 2

=item  use OSaft::Doc::Data;        # from within perl code

=item OSaft/Doc/Data --usage        # on command line will print short usage

=item OSaft/Doc/Data [COMMANDS]     # on command line will print help

=back


=head1 METHODS

=cut

#_____________________________________________________________________________
#_________________________________________________________ internal methods __|

sub _replace_var    {
    #? replace $0 by name and $VERSION by version in array, return array
    my ($name, $version, @arr) = @_;
    # SEE Perl:map()
    s#\$VERSION#$version#g  for @arr;   # add current VERSION
    s#(?<!`)\$0#$name#g     for @arr;   # my name
    return @arr;
} # _replace_var

sub _get_standalone {
    #? return help.txt with path in standalone mode
    # o-saft-standalone.pl may be in installtion path or in contrib/ directory
    # hence various places for help.txt are checked
    my $file = shift;
    $file =~ s#^\.\./##;
    $file =~ s#contrib/##;              # remove if in path
    $file =  "OSaft/Doc/$file";         # try this one ..
    $file =  "../$file" if (not -e $file);  # .. or this one
    return $file;
} # _get_standalone

sub _get_filehandle {
    #? return open file handle for passed filename,
    #? return Perl's DATA file handle of this file if file does not exist
    # this function is a wrapper for Perl's DATA
    my $file = shift || "";
    my $fh; # same as *FH
    local $\ = "\n";
    #dbx# print "#Data.pm $0, file=$file, ",__FILE__;
    if ("" ne $file) {
        # file may be in same directory as caller, or in same as this module
        if (not -e $file) {
            my  $path = __FILE__;
                $path =~ s#^/(OSaft/.*)#$1#;# own module directory
                $path =~ s#/[^/\\]*$##;     # relative path of this file
                # Dirty hack: some OS return an absolute path for  __FILE__ ;
                # then $file would not be found because that path is wrong. If
                # the path begins with /OSaft the leading / is simply removed.
                # NOTE: This behaviour (on older Mac OSX) is considered a bug
                #       in Perl there.
            $file = "$path/$file";
            # following line for gen_standalone.sh (used with make)
            # OSAFT_STANDALONE $file =  _get_standalone($file);
        }
    }
    #dbx# print "#Data.pm file=$file ";
    if ("" ne $file and -e $file) {
        ## no critic qw(InputOutput::RequireBriefOpen)
        #  file hadnle needs to be closd by caller
        if (not open($fh, '<:encoding(UTF-8)', $file)) {
            _warn("190: open('$file'): $!");
        }
    } else {
        $fh = __PACKAGE__ . "::DATA";   # same as:  *OSaft::Doc::Data::DATA
        _warn("191: no '$file' found, using '$fh'") if not -e $file;
    }
    #dbx# print "#Data.pm file=$file , FH=*$fh";
    return $fh;
} # _get_filehandle

#_____________________________________________________________________________
#__________________________________________________________________ methods __|

sub get_egg     {
    #? get easter egg from text
    my $fh      = _get_filehandle(shift);
    my $egg     = "";   # set empty to avoid "Use of uninitialized value" later
    while (<$fh>) { $egg .= $_ if (m/^#begin/..m/^#end/); }
    $egg =~ s/#(begin|end) .*\n//g;
    close($fh);
    return scalar reverse "\n$egg";
} # get_egg

=pod

=head2 get($file,$name,$version)

Return all data from file and replace $0 by $name. Returns data as string.

=cut

sub get         {
    my $file    = shift;
    my $name    = shift || "o-saft.pl";
    my $version = shift || $VERSION;
    my $fh      = _get_filehandle($file);
    return _replace_var($name, $version, <$fh>);
    # TODO: misses  close($fh);
} # get

=pod

=head2 get_as_text($file)

Return all data from file as is. Returns data as string.

=cut

sub get_as_text { my $fh = _get_filehandle(shift); return <$fh>; }
# TODO: misses  close($fh);

=pod

=head2 get_markup($file,$name,$version)

Return all data converted to internal markup format. Returns array of lines.

=cut

sub get_markup    {
    my $file    = shift;
    my $parent  = shift || "o-saft.pl";
    my $version = shift || $VERSION;
    my @txt;
    my $fh      = _get_filehandle($file);
    # Preformat plain text with markup for further simple substitutions. We
    # use a modified  &  instead of < >  POD markup as it is easy to parse.
    # &  was choosen because it rarely appears in texts and  is not  a meta
    # character in any of the supported  output formats (text, wiki, html),
    # and also causes no problems inside regex.
    for (<$fh>) {   ## no critic qw(InputOutput::ProhibitReadlineInForLoop)
                    #  There is no differnce if the array is allocated by
                    #  using a local variable or implecitely in the loop
        ## no critic qw(RegularExpressions::ProhibitComplexRegexes)
            # it's the nature of some regex to be complex
        # SEE MARKUP
        next if (m/^#begin/..m/^#end/); # remove egg
        next if (/^#/);                 # remove comments
        next if (/^\s*#.*#$/);          # remove formatting lines
        s/^([A-Z].*)/=head1 $1/;
        s/^ {4}([^ ].*)/=head2 $1/;
        s/^ {6}([^ ].*)/=head3 $1/;
        # for =item keep spaces as they are needed in man_help()
        s/^( +[a-z0-9]+\).*)/=item * $1/;# list item, starts with letter or digit and )
        s/^( +\*\* .*)/=item $1/;       # list item, second level
        s/^( +\* .*)/=item $1/;         # list item, first level
        s/^( {11})([^ ].*)/=item * $1$2/;# list item
        s/^( {14})([^ ].*)/S&$1$2&/;    # exactly 14 spaces used to highlight line
        s/^( {18})([^ ].*)/S&$1$2&/;    # exactly 18
        # quick&dirty: should not match lines starting with any of:
        #     $0 o-saft o-saft.tcl o-saft-docker checkAllCiphers.pl perl perlapp perl2exe
        # quick&dirty: should also not match  X& ... & as no other potential
        # markup should be substituted in there
        if (not m/^(?:=|S&|\s+(?:\$0|o-saft|o-saft.tcl|o-saft-docker|checkAllCiphers.pl|perl|perl2exe|perlapp)\s)/
            and not m/X&[^&]*(?:\+|--)/
           ) {  # more markup, ...
            # but not in example lines and already marked lines
            s#(\s)+(a-zA-Z[^ ]+)(\s+)#$1'$2'$3#g;   # markup literal character class as code
            s#(\s)((?:\+|--)[^,\s).]+)([,\s).])#$1I&$2&$3#g; # our commands and options
                # TODO: fails for something like:  --opt=foo="bar"
                # TODO: above substitute fails for something like:  --opt --opt
                #        hence same substitute again (should be sufficent then)
            s#([A-Z]L)&#$1 &#g; # i.e. SSL
                # quick&dirty to avoid further inerpretation of L&
                # ugly hack as it adds a space
            s#(\s)((?:\+|--)[^,\s).]+)([,\s).])#$1I&$2&$3#g;
        }
        if (not m/^S/ and not m/^ {14,}/) {
            # special markup for tools, tool name ending with (1), ... (3pm)
            s/((?:Net::SSLeay|ldd|openssl|timeout|IO::Socket(?:::SSL|::INET)?)\(\d(?:pm)?\))/L&$1&/g;
            # special markup for own tools
            s/((?:Net::SSL(?:hello|info)|o-saft(?:-dbx|-man|-usr|-README)(?:\.pm)?))/L&$1&/g;
        }
        s/  (L&[^&]*&)/ $1/g;
        s/(L&[^&]*&)  /$1 /g;
            # If external references are enclosed in double spaces, we squeeze
            # leading and trailing spaces 'cause additional characters will be
            # added later (i.e. in man_help()). Just pretty printing ...
        if (m/^ /) {
            # add internal links; quick&dirty list here
            # we only want to catch header lines, hence all capital letters
            s/ ((?:DEBUG|RC|USER)-FILE)/ X&$1&/g;
            s/ (CONFIGURATION (?:FILE|OPTIONS))/ X&$1&/g;
            s/ (SHELL TWEAKS)/ X&$1&/g;
            s/ (SEE ALSO)/ X&$1&/g;
            s/ (EXIT STATUS)/ X&$1&/g;
            s/ (CIPHER NAMES)/ X&$1&/g;
            s/ (LAZY SYNOPSIS)/ X&$1&/g;
            s/ (KNOWN PROBLEMS)/ X&$1&/g;
            s/ (BUILD DOCKER IMAGE)/ X&$1&/g;
            s/ (BUILD DOCKER IMAGE)/ X&$1&/g;
            s/ (TECHNICAL INFORMATION)/ X&$1&/g;
            s/ (NAME|CONCEPTS|ENVIRONMENT)/ X&$1&/g;
            s/ (COMMANDS|OPTIONS|RESULTS|CHECKS|OUTPUT|CUSTOMISATION) / X&$1& /g;
            s/ (LIMITATIONS|DEPENDENCIES|INSTALLATION|DOCKER|TESTING) / X&$1& /g;
            s/ (SCORING|EXAMPLES|ATTRIBUTION|DOCUMENTATION|VERSION) / X&$1& /g;
            s/ (DESCRIPTION|SYNOPSIS|QUICKSTART|SECURITY|DEBUG|AUTHOR) / X&$1& /g;
        }
        push(@txt, $_);
    }
    close($fh);
    return _replace_var($parent, $version, @txt);
} # get_markup

# NOTE: NOT YET READY, not yet used (hence no POD also)
#=pod
#
#=head2 get_text($file)
#
#Same as  get()  but with some variables substituted.
#
#=cut

sub get_text    {
    my $file    = shift;
    my $label   = shift || "";  # || to avoid "Use of uninitialised value"
       $label   = lc($label);
    my $anf     = uc($label);
    my $end     = "[A-Z]";
#   _man_dbx("man_help($anf, $end) ...");
    # no special help, print full one or parts of it
    my $txt = join ("", get_markup($file));
#   #if (1 < (grep{/^--v/} @ARGV)) {     # with --v --v
#   #    print scalar reverse "\n\n$egg";
#   #    return;
#   #}
#print "T $txt T";
    if ($label =~ m/^name/i)    { $end = "TODO";  }
    #$txt =~ s{.*?(=head. $anf.*?)\n=head. $end.*}{$1}ms;# grep all data
        # above terrible performance and unreliable, hence in peaces below
    $txt =~ s/.*?\n=head1 $anf//ms;
    $txt =~ s/\n=head1 $end.*//ms;      # grep all data
    $txt = "\n=head1 $anf" . $txt;
    $txt =~ s/\n=head2 ([^\n]*)/\n    $1/msg;
    $txt =~ s/\n=head3 ([^\n]*)/\n      $1/msg;
    $txt =~ s/\n=(?:[^ ]+ (?:\* )?)([^\n]*)/\n$1/msg;# remove inserted markup
    $txt =~ s/\nS&([^&]*)&/\n$1/g;
    $txt =~ s/[IX]&([^&]*)&/$1/g;       # internal links without markup
    $txt =~ s/L&([^&]*)&/"$1"/g;        # external links, must be last one
    if (0 < (grep{/^--v/} @ARGV)) {     # do not use $^O but our own option
        # some systems are tooo stupid to print strings > 32k, i.e. cmd.exe
        _warn("192: using workaround to print large strings.\n\n");
        print foreach split(//, $txt);  # print character by character :-((
    } else {
        #print $txt;
    }
#print "t $txt t";
    if ($label =~ m/^todo/i)    {
        print "\n  NOT YET IMPLEMENTED\n";
# TODO: {
#        foreach my $label (sort keys %checks) {
#            next if (0 >= _is_member($label, \@{$cfg{'commands-NOTYET'}}));
#            print "        $label\t- " . $checks{$label}->{txt} . "\n";
#        }
# TODO: }
    }
    return $txt;
} # get_text

=pod

=head2 print_as_text($file)

Same as  get()  but prints text directly.

=cut

sub print_as_text { my $fh = _get_filehandle(shift); print  <$fh>; return; }
# TODO: misses  close($fh);

=pod

=head1 COMMANDS

If called from command line, like

  OSaft/Doc/Data.pm COMMANDS [file]

this modules provides following COMMANDS:

=head2 VERSION

Print VERSION version.

=head2 version

Print internal version.

=head2 list

Print list of *.txt files in current directory. These files may be used for
following commands.

=head2 get filename

Call get(filename).

=head2 get_as_text filename

Call get_as_text(filename).

=head2 get_markup filename

Call get_markup(filename).

=head2 get_text filename

Call get_text(filename).

=head2 print_as_text filename

Call print_as_text(filename).

=head1 OPTIONS

=over 4

=item --V

Print VERSION version.

=back

=cut

sub list        {
    #? return sorted list of available .txt files
    #  sorted list simplifies tests ...
    my $dir = $0;
       $dir =~ s#[/\\][^/\\]*$##;
    my @txt;
    opendir(DIR, $dir) or return $!;
    while (my $file = readdir(DIR)) {
        next unless (-f "$dir/$file");
        next unless ($file =~ m/\.txt$/);
        push(@txt, $file);
    }
    closedir(DIR);
    return join("\n", sort @txt);
} # list

sub _main_usage {
    #? print usage
    my $name = (caller(0))[1];
    print "# various commands:\n";
    foreach my $cmd (qw(version +VERSION)) {
        printf("\t%s %s\n", $name, $cmd);
    }
    printf("\t$name list\t# list available files\n");
    print "# commands to get text from file in various formats(examples):\n";
    foreach my $cmd (qw(get get-markup get-text get-as-text print)) {
        printf("\t%s %s help.txt\n", $name, $cmd);
    }
    printf("\t$name ciphers=dumptab > c.csv; libreoffice c.csv\n");
    return;
}; # _main_usage

sub _main       {
    #? print own documentation or that from specified file
    ## no critic qw(InputOutput::RequireEncodingWithUTF8Layer)
    #  see t/.perlcriticrc for detailed description of "no critic"
    my @argv = @_;
    #  SEE Perl:binmode()
    binmode(STDOUT, ":unix:utf8");
    binmode(STDERR, ":unix:utf8");
    print_pod($0, __PACKAGE__, $SID_data)       if (0 > $#argv);
    # got arguments, do something special
    while (my $cmd = shift @argv) {
        my $arg    = shift @argv; # get 2nd argument, which is filename
        print_pod($0, __PACKAGE__, $SID_data)   if ($cmd =~ /^--?h(?:elp)?$/);
        _main_usage()           if ($cmd =~ /^--usage$/);
        # ----------------------------- commands
        print list() . "\n"     if ($cmd =~ /^list$/);
        print get($arg)         if ($cmd =~ /^get$/);
        print get_as_text($arg) if ($cmd =~ /^get.?as.?text/);
        print get_markup($arg)  if ($cmd =~ /^get.?mark(up)?/);
        print get_text($arg)    if ($cmd =~ /^get.?text/);
        print_as_text($arg)     if ($cmd =~ /^print$/);
        print "$SID_data\n"     if ($cmd =~ /^version$/);
        print "$VERSION\n"      if ($cmd =~ /^[-+]?V(ERSION)?$/);
    }
    exit 0;
} # _main

sub o_saft_help_done {};    # dummy to check successful include

=pod

=head1 MARKUP

Following notations / markups are used for public (user) documentation
(for example help.txt):

=over 2

=item TITLE

Titles start at beginning of a line, i.g. all upper case characters.

=item SUB-Title

Sub-titles start at beginning of a line preceeded by 4 or 6 spaces.

=item code

Code lines start at beginning of a line preceeded by 14 or more spaces.

=item "text in double quotes"

References to text or cite.

=item 'text in single quotes'

References to verbatim text elsewhere or constant string in description.

It is difficult to markup character classes like  a-zA-Z-  this way (using
quotes), because any character may be part of the class, including quotes or
those used for markup. For Example will  a-zA-Z-  look like  C<a-zA-Z->  in
POD format. Hence character classes are defined literally without markup to
avoid confusion.  However, when generating documentation it is assumed that
strings (words) beginning with  a-zA-Z  are character classes.

=item '* list item

Force list item (first level) in generated markup.

=item ** list item

Force list item (second level) in generated markup.

=item d) list item

Force list item in generated markup (d may be a digit or character).

=item $VERSION

Will be replaced by current version string (as defined in caller).

=item $0

Will be replaced by caller's name (i.g. o-saft.pl).

=item `$0'

Will not be replaced, but kept as is.

=back

Referenses to titles are written in all upper case characters and prefixed
and suffixed with 2 spaces or a . (dot) or , (comma).

There is only one special markup used:

=over 2

=item X&Some title here&

Which refers to sub-titles. It must be used to properly markup internal
links to sub-sections if the title is not written in all upper case.

=back

All head lines for sections (see TITLE above) must be preceded by 2 empty
lines. All head lines for commands and options should contain just this command
or option. Aliases for commands or options should be written in their own line
(to avoid confusion in some other parsers, like Tcl).

List items should be followed by an empty line.

Texts in section headers should not contain any quote characters.  I.g. no
other markup is used. Even lines starting with  '#'  as first character are
usually not treated as comment line but verbatim text.

=head2 Special markups

=head3 Left hand space

=over 6

=item none        - head line level 1

=item exactly 4   - head line level 2

=item exactly 6   - head line level 3

=item exactly 11  - list item

=item exactly 14  - code line

=back

=head3 Left hand *:

=over 6

=item spaces *    - list item level 1

=item spaces **   - list item level 2

=back

=head3 Left hand digit or letter followed by )

List item may start with letter or digit fowwed by ) .

=head3 Special markups for o-saft.tcl

The sub-titles in the COMMANDS and OPTIONS sections must look like:

=over 6

=item Commands for whatever text

=item Commands to whatever text

=item Options for whatever text

=back

Means that the prefixes  "Commands for"  and  "Options for"  are used to
identify groups of commands and options. If a sub-title does not start
with these prefixes, all following commands and options are ignored.

=head1 SEE ALSO

# ...

=head1 VERSION

1.41 2021/01/14

=head1 AUTHOR

17-oct-17 Achim Hoffmann

=cut

## PACKAGE }

#_____________________________________________________________________________
#_____________________________________________________________________ self __|

_main(@ARGV) if (not defined caller);

1;

# SEE Note:Documentation
# All public (user) documentation is in plain ASCII format (see help.txt).

__END__

=pod

=head1 Annotations, Internal Notes

The annotations here are for internal documentation only.
For details about our annotations, please SEE  Annotations,  in o-saft.pl.


=head3 Documentation:General

All public user documentation is written in plain text format. Therfore it
can be read without a special tool. It's designed for human radability and
simple editing.

All other formats like HTML, POD, troff (man-page), etc. will be generated
from this plain text with the methods (functions) herein.
The general workflow is as follows:

=over

=item 1. read text file

=item 2. inject simple, intermediate markup (i.g. dokuwiki style markup)

=item 3. convert intermediate markup to required format

=back

For generating some formats, external tools are used.  Such a tools mainly
gets the data in POD format and then converts it to another format. 
The external tools are called using Perl's 'exec()' function, usually.

=cut

__DATA__
