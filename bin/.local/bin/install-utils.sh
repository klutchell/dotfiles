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

install_stow()
{
	# http://www.gnu.org/software/stow/
	apt-get install "stow" -y
}

install_make()
{
	apt-get install "make" -y
}

install_etckeeper()
{
	apt-get install "etckeeper" -y
}

install_cipherscan()
{
	# https://github.com/mozilla/cipherscan
	git clone https://github.com/mozilla/cipherscan.git /opt/cipherscan
}

install_lynis()
{
	# https://cisofy.com/documentation/lynis/get-started/#installation-package
	git clone https://github.com/CISOfy/lynis /opt/lynis
}

install_hdparm()
{
	apt-get install "hdparm" -y
}

install_rclone()
{
	install_unzip
	wget 'http://downloads.rclone.org/rclone-current-linux-amd64.zip'
	unzip rclone-current-linux-amd64.zip
	cd rclone-*-linux-amd64
	cp rclone /usr/sbin/
	chown root:root /usr/sbin/rclone
	chmod 755 /usr/sbin/rclone
}

install_gdrive()
{
	wget 'https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download' -O gdrive-linux-x64
	cp gdrive-linux-x64 /usr/sbin/gdrive
	chown root:root /usr/sbin/gdrive
	chmod 755 /usr/sbin/gdrive
}

install_unionfs()
{
	apt-get install "unionfs-fuse" -y
}

install_encfs()
{
	apt-get install "encfs" -y
}

install_acdcli()
{
	install_pip3
	pip3 install --upgrade git+https://github.com/yadayada/acd_cli.git
}

install_zip()
{
	apt-get install "zip" -y
}

install_unzip()
{
	apt-get install "unzip" -y
}

install_pip()
{
	apt-get install "python-pip" -y
}

install_pip3()
{
	apt-get install "python3-pip" -y
}

install_cifs()
{
	apt-get install "cifs-utils" -y
}

install_moreutils()
{
	apt-get install "moreutils" -y
}

install_ufw()
{
	apt-get install "ufw" -y
}

install_ntp()
{
	timedatectl set-timezone 'America/New_York'
	apt-get install "ntp" -y
	ufw allow 'ntp'
}

install_openssh()
{
	apt-get install "openssh-server" -y
	ufw allow 'OpenSSH'
}

install_fail2ban()
{
	apt-get install "fail2ban" -y
}

install_nano()
{
	apt-get install "nano" -y
}

install_git()
{
	add-apt-repository ppa:git-core/ppa -y
	apt-get update
	apt-get install "git" -y
}

install_rsnapshot()
{
	apt-get install "rsnapshot" -y
}

install_common()
{
	install_ufw
	install_ntp
	install_openssh
	install_git
	install_fail2ban
	install_nano
	install_moreutils
	install_stow
	install_make
}

usage()
{
	echo "usage: $THIS [utilities]"
	echo "utilities:"
	compgen -A function | sed -nr 's|^install_(.+)$| \1|p'
	exit 1
}

pushd "$SCRATCH" >/dev/null

apt-get update
eval "install_${1}" || usage

popd >/dev/null
