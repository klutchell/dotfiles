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

if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

# gdrive config
GDRIVE_CONFIG="/home/kyle/.gdrive"
GDRIVE_PARENT="0B8Hwaj3ywtn-dTVmN2FnZUpseDA"
GDRIVE_OUTFILE="outfile"

# snapshot path and timestamp
SNAPSHOT="/data/.snapshots/alpha.0/localhost"
TARBALL="$(hostname)_$(date -r "$SNAPSHOT" +%Y.%m.%d_%H.%M.%S).tar.gz"

# compress
pushd "$SNAPSHOT" >/dev/null
echo "compressing $SNAPSHOT into $TARBALL..."
tar -czf "$SCRATCH/$TARBALL" *
popd >/dev/null

# move to scratch
pushd "$SCRATCH" >/dev/null

# list snapshots
/usr/sbin/gdrive -c "$GDRIVE_CONFIG" list --query "name contains '$(hostname)' and '$GDRIVE_PARENT' in parents and trashed = false" --order "createdTime desc" > "$GDRIVE_OUTFILE"
cat "$GDRIVE_OUTFILE"

# upload or update
FILE_ID="$(grep "$TARBALL" "$GDRIVE_OUTFILE" | head -n1 | cut -d' ' -f1)" || true
if [ -n "$FILE_ID" ]; then
	/usr/sbin/gdrive -c "$GDRIVE_CONFIG" update "$FILE_ID" "$SCRATCH/$TARBALL"
else
	/usr/sbin/gdrive -c "$GDRIVE_CONFIG" upload -p "$GDRIVE_PARENT" "$SCRATCH/$TARBALL"
fi

# list snapshots
/usr/sbin/gdrive -c "$GDRIVE_CONFIG" list --query "name contains '$(hostname)' and '$GDRIVE_PARENT' in parents and trashed = false" --order "createdTime desc" > "$GDRIVE_OUTFILE"
cat "$GDRIVE_OUTFILE"

# delete oldest
SNAPSHOT_COUNT="$(($(cat $GDRIVE_OUTFILE | wc -l)-1))"
if [ "$SNAPSHOT_COUNT" -gt 7 ]; then
	FILE_ID="$(tail -n1 $GDRIVE_OUTFILE | cut -d' ' -f1)"
	/usr/sbin/gdrive -c "$GDRIVE_CONFIG" delete "$FILE_ID"
fi

popd >/dev/null
