#!/bin/sh
test -z "$D" && D=:1017
S=`dirname $0`
#OP="-d"
test -z "$S" && S="."
scp -q $S/userman.pl ps:/usr/local/bin/userman.pl
ssh ps "DISPLAY=$D perl /usr/local/bin/userman.pl $OP"
