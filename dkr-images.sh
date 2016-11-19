#!/usr/bin/env bash

set -eo pipefail

abs() { echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"; }

THIS="$(basename "$0")"
BIN="$(dirname "$(abs "${BASH_SOURCE[0]}")")"
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

if [ "$(id -u)" = "0" ]; then
	echo "This script should not be run as root" 1>&2
	exit 1
fi

escape_spaces()
{
	echo "$1" | sed 's|_|\\ |g'
}

list_images()
{
	local cmd="docker images"
	echo $cmd
	eval $cmd
}

clean_images()
{
	local cmd="docker images -q -a | xargs --no-run-if-empty docker rmi"
	echo $cmd
	eval $cmd || true
}

usage()
{
	echo "usage: $THIS <action>"
	echo "actions:"
	compgen -A function | sed -rn 's|^(.+)_images$| \1|p'
	exit 1
}

# move to scratch
pushd "$SCRATCH" >/dev/null

eval "${1}_images" || usage

popd >/dev/null
