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

clean_dir()
{
	while IFS= read -r -d '' dir
	do
		[ -d "$dir" ] || continue
		[ "$dir" = "$1" ] && continue
		
		dir_size=$(du -sk "$dir" 2>/dev/null | cut -f1)
		
		if [ "$dir_size" -lt "$2" ]; then
			echo "removing $dir ($dir_size KB)..."
			rm -rvf "$dir"
		fi
	done <   <(find "$1" -maxdepth 1 -type d -mtime "$3" -print0)
}

pushd "$SCRATCH" >/dev/null

# movies, 200MB, 14 days
clean_dir "/data/plex/movies" "200000" "+14" 

# tv, 20MB, 14 days
clean_dir "/data/plex/tv" "20000" "+14" 

popd >/dev/null