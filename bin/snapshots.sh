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

# snapshots config
SNAPSHOTS_CONFIG="$BIN/snapshots.conf"
GDRIVE_OUTFILE=gdrive_outfile.tmp
PATH_LIST=path_list.tmp

[ -f "$SNAPSHOTS_CONFIG" ] || { echo "SNAPSHOTS_CONFIG '$SNAPSHOTS_CONFIG' does not exist"; exit 1; }

. "$SNAPSHOTS_CONFIG"

[ -d "$GDRIVE_CONFIG" ] || { echo "GDRIVE_CONFIG '$GDRIVE_CONFIG' is not valid"; exit 1; }
[ -n "$GDRIVE_PARENT" ] || { echo "GDRIVE_PARENT '$GDRIVE_PARENT' is not valid"; exit 1; }

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

snapshot_list()
{
	# list snapshots
	/usr/sbin/gdrive -c "$GDRIVE_CONFIG" list --query "'$GDRIVE_PARENT' in parents and trashed = false" --order "createdTime desc" > "$GDRIVE_OUTFILE"
	cat "$GDRIVE_OUTFILE"
}

snapshot_upload()
{
	[ -d "$SNAPSHOT_DIR" ] || { echo "SNAPSHOT_DIR '$SNAPSHOT_DIR' is not valid"; exit 1; }
	
	# tarball name includes timestamp of the snapshot dir
	TARBALL="$(hostname)_$(date -r "$SNAPSHOT_DIR" +%Y.%m.%d_%H.%M.%S).tar.gz"

	# compress
	pushd "$SNAPSHOT_DIR" >/dev/null
	echo "compressing $SNAPSHOT_DIR into $TARBALL..."
	tar -czf "$SCRATCH/$TARBALL" *
	popd >/dev/null

	# upload or update
	FILE_ID="$(grep "$TARBALL" "$GDRIVE_OUTFILE" | head -n1 | cut -d' ' -f1)" || true
	if [ -n "$FILE_ID" ]; then
		/usr/sbin/gdrive -c "$GDRIVE_CONFIG" update "$FILE_ID" "$SCRATCH/$TARBALL"
	else
		/usr/sbin/gdrive -c "$GDRIVE_CONFIG" upload -p "$GDRIVE_PARENT" "$SCRATCH/$TARBALL"
	fi

	# delete oldest
	SNAPSHOT_COUNT="$(($(cat $GDRIVE_OUTFILE | wc -l)-1))"
	if [ "$SNAPSHOT_COUNT" -gt 7 ]; then
		FILE_ID="$(tail -n1 $GDRIVE_OUTFILE | cut -d' ' -f1)"
		/usr/sbin/gdrive -c "$GDRIVE_CONFIG" delete "$FILE_ID"
	fi
}

snapshot_download()
{
	[ -n "$EXTRACT_DIR" ] || { echo "EXTRACT_DIR '$EXTRACT_DIR' is not valid"; exit 1; }
	[ -n "$RESTORE_PATHS" ] || { echo "RESTORE_PATHS '$RESTORE_PATHS' is not valid"; exit 1; }
	
	snapshot_list
	
	while true; do
		read -p "enter file id:" FILE_ID
		grep -q "$FILE_ID" "$GDRIVE_OUTFILE" && break
		echo "please enter a valid file id"
	done

	# download file
	rm "$GDRIVE_OUTFILE" 2>/dev/null || true
	/usr/sbin/gdrive -c "$GDRIVE_CONFIG" download --stdout "$FILE_ID" > "$GDRIVE_OUTFILE"
	
	rm "$PATH_LIST" 2>/dev/null || true
	for path in $RESTORE_PATHS; do
		echo "$path" >> "$PATH_LIST"
	done

	# list restore files
	cat "$PATH_LIST"

	# confirm action
	echo "are you sure you want to restore these files to $EXTRACT_DIR?"
	confirm_action || exit

	# extract
	echo "extracting files to $EXTRACT_DIR..."
	mkdir "$EXTRACT_DIR" 2>/dev/null || true
	tar xzpvf "$GDRIVE_OUTFILE" -C "$EXTRACT_DIR" -T "$PATH_LIST"
}

usage()
{
	echo "usage: $THIS [action]"
	echo "actions:"
	compgen -A function | sed -rn 's|^snapshot_(.+)$| \1|p'
	exit 1
}

# move to scratch
pushd "$SCRATCH" >/dev/null

eval "snapshot_${1}" || usage

popd >/dev/null