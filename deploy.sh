#!/bin/sh
test -z "$D" && D=:1014
S=`dirname $0`
test -z "$S" && S="."
scp -q $S/ldap-gui.pl ps:/usr/local/bin/ldap-gui.pl
ssh ps "DISPLAY=$D /usr/local/bin/ldap-gui.pl"
