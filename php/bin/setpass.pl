#!/usr/bin/perl
#
# Requires: perl-ldap, perl-IO-Socket-SSL
#
# usage: setpass.pl <uri> <bind_dn> <bind_pass> <user_dn> <new_pass>
#
# LDAP library in PHP does not support the PASSMOD action from RFC 3062.
# The SetPassword extension is absent in contrast to Net::LDAP in Perl.
# As a workaround we use this Perl helper script.
#

use strict;
use Net::LDAP;
use Net::LDAP::Extension::SetPassword;

use constant TIMEOUT => 10;
use constant DEBUG => 0;

my @args = @ARGV;
for my $i (0 .. $#args) {
    if ($args[$i] eq '-') {
        $args[$i] = <STDIN>;
        chomp $args[$i];
    }
}

my ($uri, $bind_dn, $bind_pass, $user_dn, $new_pass) = @args;
print "uri=$uri bind_dn=$bind_dn bind_pass=$bind_pass user_dn=$user_dn new_pass=$new_pass\n" if DEBUG;

my $ldap = Net::LDAP->new($uri, timeout => TIMEOUT);
die "Connection failure\n" unless defined $ldap;

my $res = $ldap->bind($bind_dn, password => $bind_pass);
die "Bind: ".$res->error."\n" if $res->code;

$res = $ldap->set_password(user => $user_dn, newpasswd => $new_pass);
die "SetPassword: ".$res->error."\n" if $res->code;

print "OK\n" if DEBUG;
exit 0;

