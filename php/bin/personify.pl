#!/usr/bin/perl
# $Id$
#
# Multi-file string substitutor
#
# usage: personify.pl DIR EXCLUSIONS SUBST1 [SUBST2...]
#
#

use strict;
use constant DEBUG => 0;

my ($root_dir, $arg_excl, @arg_repl) = @ARGV;

my (%repl, @excl);
@excl = split /\|/, $arg_excl;
for my $arg (@arg_repl) {
    my ($key, $val) = split /\|/, $arg;
    $repl{$key} = $val;
}

sub personify_node ($)
{
    my $dir = shift;

    for my $path (glob("$dir/*"), glob("$dir/.*"))
    {
        my $skip = 0;
        next if $path =~ /\/\.\.?$/;
        $path =~ /^(.*?)\/([^\/]+)$/;
        my ($dir, $file) = ($1, $2);
        my $nfile = $file;

        for my $s (keys %repl) {
            my $d = $repl{$s};
            $nfile =~ s/$s/$d/ge;
        }

        if ($file ne $nfile) {
            my $npath = "$dir/$nfile";
            print "personify: rename: $path ==> $npath\n" if DEBUG;
            rename($path, $npath);
            $path = $npath;
        }
        next if -l $path;

        for my $pat (@excl) {
            if ($file =~ /$pat/) {
                print "personify: excluding: $path\n" if DEBUG;
                $skip = 1;
                last;
            }
        }
        next if $skip;

        if (-d $path) {
            personify_node($path);
            next;
        }
        next unless -r $path;

        my $tpath = "$path.temp-replace.$$.tmp";
        my ($_dev,$_ino,$mode,$_nlink,$uid,$gid,@_unused) = stat($path);

        # read complete file into $contents
        my $oldsep = $/;
        $/ = undef;
        open(IN, "<:raw", $path);
        my $contents = <IN>;
        close(IN);
        $/ = $oldsep;
		next unless defined $contents;

        $skip = 1;
        for my $s (keys %repl) {
            if ($contents =~ /$s/) {
                $skip = 0;
                last;
            }
        }
        undef $contents;
        next if $skip;

        open(IN, "<:raw", $path);
        open(OUT, ">:raw", $tpath);
        $skip = 1;
        while(<IN>) {
            my $src = $_;
            my $dst = $_;
            for my $s (keys %repl) {
                my $d = $repl{$s};
                $dst =~ s/$s/$d/gx;
            }
            $skip = 0 if $src ne $dst;
            print OUT $dst;
        }
        close(IN);
        close(OUT);

        if ($skip) {
            unlink($tpath);
            next;
        }

        chown($uid, $gid, $tpath);
        chmod($mode, $tpath);
        unlink($path);
        rename($tpath, $path);
        print "personify: changed: $path\n" if DEBUG;
    }
}

personify_node($root_dir);
exit 0;

