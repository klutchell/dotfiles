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

pushd "$SCRATCH" >/dev/null

echo "unmount unionfs /mnt/union..."
/bin/fusermount -uz "/mnt/union" || true

echo "unmount encfs /mnt/acd..."
/bin/fusermount -uz "/mnt/acd" || true

echo "unmount encfs /mnt/local..."
/bin/fusermount -uz "/mnt/local" || true

echo "unmount acd /mnt/.acd..."
/bin/fusermount -uz "/mnt/.acd" || true

echo "mount acd /mnt/.acd..."
/usr/local/bin/acd_cli sync
/usr/local/bin/acd_cli mount -ao -ro --uid 1000 --gid 1000 --umask 0007 /mnt/.acd

echo "mount encfs /mnt/acd..."
ENCFS6_CONFIG='/root/.encfs/encfs.xml' /usr/bin/encfs -o allow_other,nonempty,uid=1000,gid=1000,umask=0007 --extpass="cat /root/.encfs/credentials.txt" "/mnt/.acd/encrypted" "/mnt/acd"

echo "mount encfs /mnt/local..."
ENCFS6_CONFIG='/root/.encfs/encfs.xml' /usr/bin/encfs -o allow_other,nonempty,uid=1000,gid=1000,umask=0007 --extpass="cat /root/.encfs/credentials.txt" "/mnt/.local/encrypted" "/mnt/local"

echo "mount unionfs /mnt/union..."
/usr/bin/unionfs-fuse -o cow,allow_other,uid=1000,gid=1000,umask=0007 /mnt/local=RW:/mnt/acd=RO /mnt/union/

#echo "unmount encfs /mnt/backup-server..."
#/bin/umount "/mnt/backup-server" || true

#echo "unmount cifs /mnt/.backup-server..."
#/bin/umount "/mnt/.backup-server" || true

#echo "mount cifs /mnt/.backup-server..."
#/sbin/mount.cifs -o iocharset=utf8,rw,credentials=/root/.cifs/credentials.txt,uid=kyle,gid=kyle,file_mode=0660,dir_mode=0770,nounix,user,noauto "$(head -n1 /root/.cifs/server.txt)" "/mnt/.backup-server"

#echo "mount encfs /mnt/backup-server..."
#ENCFS6_CONFIG='/root/.encfs/encfs.xml' /usr/bin/encfs -o allow_other,nonempty --extpass="cat /root/.encfs/credentials.txt" "/mnt/.backup-server/encrypted" "/mnt/backup-server"

popd >/dev/null
