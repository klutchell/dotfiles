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

if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

confirm_action()
{
	while true; do
		read -p "(y/N): " yn
		case $yn in
			[Yy]* ) return 0;;
			* ) return 1;;
		esac
	done
}

migrate_all()
{
	rsync -arzPvhe ssh --bwlimit=$BWLIMIT --no-implied-dirs --relative --files-from="$FILES_FROM" / $DESTINATION:/
}

migrate_test()
{
	rsync -arzPvhe ssh --bwlimit=$BWLIMIT --no-implied-dirs --relative --dry-run --files-from="$FILES_FROM" / $DESTINATION:/
}

usage()
{
	echo "usage: $THIS [action] [destination]"
	echo "actions:"
	compgen -A function | sed -rn 's|^migrate_(.+)$| \1|p'
	exit 1
}

# snapshots config
MIGRATE_CONFIG="$BIN/migrate.conf"
ACTION="$1"
DESTINATION="$2"

[ -f "$MIGRATE_CONFIG" ] || { echo "MIGRATE_CONFIG '$MIGRATE_CONFIG' does not exist"; exit 1; }
[ -n "$ACTION" ] || usage
[ -n "$DESTINATION" ] || usage

. "$MIGRATE_CONFIG"

# move to scratch
pushd "$SCRATCH" >/dev/null

FILES_FROM=files_from.tmp
rm "$FILES_FROM" 2>/dev/null || true
for file in $MIGRATE_PATHS; do
	echo "$file" >> "$FILES_FROM"
done

eval "migrate_${ACTION}" || usage

popd >/dev/null