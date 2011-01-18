#!/bin/sh
# $Id$
#
# This helper shall be added to sudoers for apache/nginx user
#
# usage: suhelper.sh ACTION DIRECTORY [PARAMS...]
#
#set -x
LANG=C
export LANG

case "$1" in
    cp_dir)
        # usage: suhelper.sh cp_dir DIR SKEL_DIR UID GID
        [ -z "$5" ] && echo "$1: wrong usage" && exit 1
        [ ! -d "$3" ] && echo "$2: skeleton is not a directory" && exit 1
        [ -e "$2" ] && echo "$3: home directory already exists" && exit 0
        /bin/cp -r "$3" "$2" || exit 1
        /bin/chown -R "$4":"$5" "$2" || exit 1
        ;;
    rm_dir)
        # usage: suhelper.sh rm_dir DIR
        [ -z "$2" ] && echo "$1: wrong usage" && exit 1
        /bin/rm -rf "$2" || exit 1
        exit 0
        ;;
    subst)
        # usage: suhelper.sh subst DIR EXCLUSIONS SUBST1 [SUBST2...]
        [ ! -x ./personify.pl ] && echo "personify.pl not found" && exit 1
        [ -z "$4" ] && echo "$1: wrong usage" && exit 1
        shift
        ./personify.pl "$*"
        exit $?
        ;;
    *)
        echo "$1: wrong usage"
        exit 1
        ;;
esac

