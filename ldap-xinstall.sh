#!/bin/sh
#echo "$@"
test -z "$4" && exit 1
/bin/cp -r -p "$3" "$4"
/bin/chown -R "$1" "$4"
/bin/chgrp -R "$2" "$4"
