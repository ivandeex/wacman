#!/bin/bash
#
# ldap-refresh-etc This shell script starts/stops the LDAP refresher
#
# chkconfig: - 22 78
#
# processname: lda-refresh
# description: LDAP refresher
#

NAME="ldap-refresh"
PIDFILE=/var/run/ldap-refresh.pid
OUTFILE=/var/log/ldap-refresh.out
SCRIPT=/usr/local/sbin/ldap-refresh.pl
OPTIONS="-d"

PID=""

getpid()
{
  PID=""
  if [ -r $PIDFILE ]; then
    PID=`< $PIDFILE`
    kill -0 $PID 2> /dev/null && return 0
  fi
  return 1
}

status()
{
  getpid && echo "$NAME running ($PID)" || echo "$NAME not running"
}

stop()
{
  while getpid; do
    echo "stopping $NAME ($PID)"
    kill -TERM $PID
    sleep 1
  done
  rm -f $PIDFILE
}

start()
{
  if getpid; then
    echo "$NAME already running ($PID)"
  else
    nohup $SCRIPT $OPTIONS > $OUTFILE 2>&1 &
    if ! getpid; then
      sleep 1
    fi
    getpid && echo "start $NAME: success ($PID)" || echo "start $NAME: failure"
  fi
}

case "$1" in
 
start)
  start
  ;;
 
stop)
  stop
  ;;

restart)
  stop
  start
  ;;

status)
  status
  ;;

*)
  echo "usage: $0  start | stop | status"
  ;;

esac

