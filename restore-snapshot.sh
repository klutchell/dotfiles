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

GDRIVE_CONFIG="~/.gdrive"
GDRIVE_PARENT="$(head -n1 "$GDRIVE_CONFIG"/snapshot-parent.txt)"
GDRIVE_OUTFILE="outfile"

RESTORE_FILES="$GDRIVE_CONFIG/restore-files.txt"
EXTRACT_DIR="/"
TARBALL="snapshot.tar.gz"

pushd "$SCRATCH" >/dev/null

/usr/sbin/gdrive -c "$GDRIVE_CONFIG" list --query "'$GDRIVE_PARENT' in parents and trashed = false" --order "createdTime desc" > "$GDRIVE_OUTFILE"
cat "$GDRIVE_OUTFILE"

while true; do
	read -p "enter file id:" FILE_ID
	grep -q "$FILE_ID" "$GDRIVE_OUTFILE" && break
	echo "please enter a valid file id"
done

rm "$GDRIVE_OUTFILE" 2>/dev/null || true
/usr/sbin/gdrive -c "$GDRIVE_CONFIG" download --stdout "$FILE_ID" > "$GDRIVE_OUTFILE"

cat "$RESTORE_FILES"

while true; do
	read -p "are you sure you want to restore these files to $EXTRACT_DIR?" yn
	case $yn in
		[Yy]* ) break;;
		[Nn]* ) exit;;
		* ) echo "please answer yes or no";;
	esac
done

echo "extracting files to $EXTRACT_DIR..."
sudo sh -c 'mkdir "$EXTRACT_DIR" 2>/dev/null || true
tar xzpvf "$GDRIVE_OUTFILE" -C "$EXTRACT_DIR" -T "$RESTORE_FILES"'

popd >/dev/null