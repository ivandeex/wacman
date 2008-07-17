#!/bin/sh
D=:1012
S=`dirname $0`
test -z "$S" && S="."
scp -q $S/ldap-gui.pl ps:/usr/local/bin/ldap-gui.pl
ssh ps "DISPLAY=$D /usr/local/bin/ldap-gui.pl"