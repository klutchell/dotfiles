#!/usr/bin/env bash

set -eo pipefail

abs() { echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"; }

THIS="$(basename "$0")"
HERE="$(dirname "$(abs "${BASH_SOURCE[0]}")")"
PID="/tmp/${THIS%.*}.pid"
LOG="/tmp/${THIS%.*}.log"
SCRATCH="$(mktemp -d -t tmp.XXXXXXXXXX)"

finish()
{
	local rc=$?
	echo "exited $THIS with error level $rc"
	[ -f "$PID" ] && [ "$(cat "$PID")" = "$$" ] && rm "$PID" &>/dev/null
	popd &>/dev/null || true
	rm -rf "$SCRATCH" &>/dev/null || true
	exit $rc
}
trap finish INT TERM EXIT

# redirect output to log
[ -t 1 ] || exec &> >(ts >>"$LOG")

# exit if pid exists
[ -f "$PID" ] && { echo "$THIS is already running!"; exit 2; }

# start a new pid
echo $$ > "$PID"

# print arguments
echo "running $THIS $@"

# lower script priority
/usr/bin/renice -n 19 -p $$ &>/dev/null
/usr/bin/ionice -c 2 -n 7 -p $$ &>/dev/null

usage()
{
	echo "usage: $THIS [start|stop|restart|status|reload|enable|disable|is-enabled|is-active]"
	exit 1
}

case $1 in
	"start")
		action=$1;;
	"stop")
		action=$1;;
	"restart")
		action=$1;;
	"status")
		action=$1;;
	"reload")
		action=$1;;
	"enable")
		action=$1;;
	"disable")
		action=$1;;
	"is-enabled")
		action=$1;;
	"is-active")
		action=$1;;
	*)
		usage;;
esac

pushd "$SCRATCH" >/dev/null
for serv in plexmediaserver plexpy nzbget nzbdrone couchpotato transmission-daemon; do
	echo "systemctl $action $serv..."
	sudo systemctl "$action" "$serv" || true
done
popd >/dev/null
