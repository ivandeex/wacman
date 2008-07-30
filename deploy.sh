#!/bin/sh
test -z "$D" && D=:1014
S=`dirname $0`
test -z "$S" && S="."
scp -q $S/userman.pl ps:/usr/local/bin/userman.pl
ssh ps "DISPLAY=$D /usr/local/bin/userman.pl"
