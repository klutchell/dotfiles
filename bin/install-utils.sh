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
	#apt-get install "lynis" -y
	
	git clone https://github.com/CISOfy/lynis /opt/lynis
}

install_hdparm()
{
	apt-get install "hdparm" -y
}

install_glances()
{
	# https://pypi.python.org/pypi/Glances
	# download & install
	curl -L https://bit.ly/glances | /bin/bash
}

install_rclone()
{
	# requires unzip
	install_unzip

	# download
	wget 'http://downloads.rclone.org/rclone-current-linux-amd64.zip'

	# extract
	unzip rclone-current-linux-amd64.zip
	cd rclone-*-linux-amd64

	# install
	cp rclone /usr/sbin/
	chown root:root /usr/sbin/rclone
	chmod 755 /usr/sbin/rclone
}

install_gdrive()
{
	# download
	wget 'https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download' -O gdrive-linux-x64

	# install
	cp gdrive-linux-x64 /usr/sbin/gdrive
	chown root:root /usr/sbin/gdrive
	chmod 755 /usr/sbin/gdrive
}

install_unionfs()
{
	# install
	apt-get install "unionfs-fuse" -y
}

install_acdcli()
{
	# requires pip3
	install_pip3

	# install
	pip3 install --upgrade git+https://github.com/yadayada/acd_cli.git
}

install_zip()
{
	# install
	apt-get install "zip" -y
}

install_unzip()
{
	# install
	apt-get install "unzip" -y
}

install_pip()
{
	# install
	apt-get install "python-pip" -y
}

install_pip3()
{
	# install
	apt-get install "python3-pip" -y
}

install_cifs()
{
	# install
	apt-get install "cifs-utils" -y
}

install_encfs()
{
	# install
	apt-get install "encfs" -y

	# allow other
	sed -i 's|#user_allow_other|user_allow_other|' /etc/fuse.conf
}

install_moreutils()
{
	# install
	apt-get install "moreutils" -y
}

install_ufw()
{
	# install
	apt-get install "ufw" -y
}

install_ntp()
{
	# set timezone
	timedatectl set-timezone 'America/New_York'

	# install
	apt-get install "ntp" -y

	# configure firewall
	ufw allow 'ntp'
}

install_openssh()
{
	# install
	apt-get install "openssh-server" -y

	# configure firewall
	ufw allow 'OpenSSH'
}

install_fail2ban()
{
	# install
	apt-get install "fail2ban" -y
}

install_nginx()
{
	# install
	apt-get install "nginx" -y

	# configure firewall
	ufw allow 'Nginx Full'
}

install_nano()
{
	# install
	apt-get install "nano" -y
}

install_git()
{
	# install
	apt-get install "git" -y
}

install_rsnapshot()
{
	# install
	apt-get install "rsnapshot" -y
}

install_docker()
{
	# install
	# https://docs.docker.com/engine/installation/linux/ubuntulinux/
	curl -sSL get.docker.com | sh

	# configure user
	usermod -aG docker "kyle"

	# disable iptable modifications
	# https://fralef.me/docker-and-iptables.html
	if [ ! -f "/etc/systemd/system/docker.service.d/noiptables.conf" ]; then
		mkdir /etc/systemd/system/docker.service.d 2>/dev/null || true
		echo -e "[Service]\nExecStart=\nExecStart=/usr/bin/docker daemon -H fd:// --iptables=false --dns 8.8.8.8 --dns 8.8.4.4\n" > /etc/systemd/system/docker.service.d/noiptables.conf
		systemctl daemon-reload
	fi

	# configure firewall
	# https://svenv.nl/unixandlinux/dockerufw
	if ! grep -q "docker0" /etc/ufw/before.rules; then
		awk '!NF&&a==""{print "\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE\nCOMMIT\n";a=1}1' /etc/ufw/before.rules > /etc/ufw/before.rules.tmp
		mv /etc/ufw/before.rules.tmp /etc/ufw/before.rules
	fi
	sed -i 's|DEFAULT_FORWARD_POLICY=.*|DEFAULT_FORWARD_POLICY="ACCEPT"|' /etc/default/ufw
	ufw reload
	ufw allow 2375/tcp

	# start
	service docker start

	# start on boot
	systemctl enable docker
}

install_common()
{
	install_ufw
	install_ntp
	install_openssh
	install_git
	install_fail2ban
	install_rsnapshot
	install_nano
	install_moreutils
	install_docker
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
