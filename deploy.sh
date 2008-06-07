#!/bin/sh
set -x
SCP=scp
SSH=ssh
SRV=el4
SRC=`dirname $0`
test -z "$SRC" && SRC="."
$SCP $SRC/ldap-refresh.pl $SRV:/usr/local/sbin/ldap-refresh.pl
$SCP $SRC/ldap-xinstall.sh $SRV:/usr/local/sbin/ldap-xinstall.sh
$SCP $SRC/ldap-refresh.cfg $SRV:/etc/ldap-refresh.cfg
$SCP $SRC/ldap-refresh-etc.sh $SRV:/etc/init.d/ldap-refresh
$SSH $SRV /etc/init.d/ldap-refresh restart