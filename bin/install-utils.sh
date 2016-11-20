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

install_lynis()
{
	# https://cisofy.com/download/lynis/
	# download
	wget https://cisofy.com/files/lynis-2.4.0.tar.gz
	
	# extract
	tar xvf lynis-2.4.0.tar.gz
	
	# install
	mv lynis /opt/
	chown -R root:root /opt/lynis
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
	# requires pip
	install_pip

	# install
	pip3 install --upgrade git+https://github.com/yadayada/acd_cli.git
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

install_python()
{
	# install
	apt-get install "python" -y
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
	# check if already installed
	if [ "$(dpkg-query -W -f='${Status}' docker-engine 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
		echo "package docker-engine is already installed" && return
	fi

	# https://docs.docker.com/engine/installation/linux/ubuntulinux/

	# prerequisites
	apt-get update
	apt-get install apt-transport-https ca-certificates -y
	apt-get install linux-image-extra-$(uname -r) linux-image-extra-virtual -y

	# add key
	apt-get install gnupg -y
	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
	echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | tee /etc/apt/sources.list.d/docker.list

	# install
	apt-get update
	apt-get install docker-engine -y

	# configure user
	groupadd docker || true
	usermod -aG docker "kyle" || true

	# disable iptable modifications
	# https://fralef.me/docker-and-iptables.html
	mkdir /etc/systemd/system/docker.service.d || true
	echo -e "[Service]\nExecStart=\nExecStart=/usr/bin/docker daemon -H fd:// --iptables=false --dns 8.8.8.8 --dns 8.8.4.4\n" > /etc/systemd/system/docker.service.d/noiptables.conf
	systemctl daemon-reload

	# configure firewall
	# https://svenv.nl/unixandlinux/dockerufw
	awk '!NF&&a==""{print "\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE\nCOMMIT\n";a=1}1' /etc/ufw/before.rules > /etc/ufw/before.rules.tmp
	mv /etc/ufw/before.rules.tmp /etc/ufw/before.rules
	
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
	install_lynis
	install_unzip
	# install_python
	# install_pip
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
