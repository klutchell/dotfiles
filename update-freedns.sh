#!/usr/bin/env bash

set -eo pipefail

abs_dir()
{
	echo "$(cd "$(dirname "${1}")" && pwd)"
}

abs_file()
{
	echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"
}

THIS="$(basename "$0")"
HERE="$(abs_dir "${BASH_SOURCE[0]}")"
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

FREEDNS_CONFIG="~/.freedns"
FREEDNS_URL="$(head -n1 "$FREEDNS_CONFIG"/freedns-url.txt)"

pushd "$SCRATCH" >/dev/null

# sleep for random 0 to 59 minutes
sleep $(( $(od -N1 -tuC -An /dev/urandom) % 59 ))m

# update freedns with current ip
wget -O - "$FREEDNS_URL"

popd >/dev/null