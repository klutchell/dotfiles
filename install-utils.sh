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

if [ "$(id -u)" = "0" ]; then
	echo "This script should not be run as root" 1>&2
	exit 1
fi

apt_install()
{
	# check if already installed
	if [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
		echo "package $1 is already installed" && return
	fi

	# install
	sudo apt-get update
	sudo apt-get install "$1" -y
}

install_lynis()
{
	# https://cisofy.com/download/lynis/
	# download
	wget https://cisofy.com/files/lynis-2.4.0.tar.gz
	
	# extract
	tar xvf lynis-2.4.0.tar.gz
	
	# install
	sudo mv lynis /opt/
	sudo chown -R root:root /opt/lynis
}

install_hdparm()
{
	apt_install "hdparm"
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
	sudo cp rclone /usr/sbin/
	sudo chown root:root /usr/sbin/rclone
	sudo chmod 755 /usr/sbin/rclone
}

install_gdrive()
{
	# download
	wget 'https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download' -O gdrive-linux-x64

	# install
	sudo cp gdrive-linux-x64 /usr/sbin/gdrive
	sudo chown root:root /usr/sbin/gdrive
	sudo chmod 755 /usr/sbin/gdrive
}

install_unionfs()
{
	# install
	apt_install "unionfs-fuse"
}

install_acdcli()
{
	# requires pip
	install_pip

	# install
	sudo pip3 install --upgrade git+https://github.com/yadayada/acd_cli.git
}

install_unzip()
{
	# install
	apt_install "unzip"
}

install_pip()
{
	# install
	apt_install "python-pip"
}

install_python()
{
	# install
	apt_install "python"
}

install_cifs()
{
	# install
	apt_install "cifs-utils"
}

install_encfs()
{
	# install
	apt_install "encfs"

	# allow other
	sudo sed -i 's|#user_allow_other|user_allow_other|' /etc/fuse.conf
}

install_moreutils()
{
	# install
	apt_install "moreutils"
}

install_ufw()
{
	# install
	apt_install "ufw"
}

install_ntp()
{
	# set timezone
	sudo timedatectl set-timezone 'America/New_York'

	# install
	apt_install "ntp"

	# configure firewall
	sudo ufw allow 'ntp'
}

install_openssh()
{
	# install
	apt_install "openssh-server"

	# configure firewall
	sudo ufw allow 'OpenSSH'
}

install_fail2ban()
{
	# install
	apt_install "fail2ban"
}

install_nginx()
{
	# install
	apt_install "nginx"

	# configure firewall
	sudo ufw allow 'Nginx Full'
}

install_nano()
{
	# install
	apt_install "nano"
}

install_git()
{
	# install
	apt_install "git"
}

install_rsnapshot()
{
	# install
	apt_install "rsnapshot"
}

install_docker()
{
	# check if already installed
	if [ "$(dpkg-query -W -f='${Status}' docker-engine 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
		echo "package docker-engine is already installed" && return
	fi

	# https://docs.docker.com/engine/installation/linux/ubuntulinux/

	# prerequisites
	sudo apt-get update
	sudo apt-get install apt-transport-https ca-certificates -y
	sudo apt-get install linux-image-extra-$(uname -r) linux-image-extra-virtual -y

	# add key
	sudo apt-get install gnupg -y
	sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
	sudo echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list

	# install
	sudo apt-get update
	sudo apt-get install docker-engine -y

	# configure user
	sudo groupadd docker || true
	sudo usermod -aG docker "$(whoami)" || true

	# disable iptable modifications
	# https://fralef.me/docker-and-iptables.html
	sudo mkdir /etc/systemd/system/docker.service.d || true
	sudo sh -c 'echo -e "[Service]\nExecStart=\nExecStart=/usr/bin/docker daemon -H fd:// --iptables=false --dns 8.8.8.8 --dns 8.8.4.4\n" > /etc/systemd/system/docker.service.d/noiptables.conf'
	sudo systemctl daemon-reload

	# configure firewall
	# https://svenv.nl/unixandlinux/dockerufw
	#sudo sh -c 'echo -e "*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE\nCOMMIT\n$(cat /etc/ufw/before.rules)" > /etc/ufw/before.rules'
	sudo awk '!NF&&a==""{print "\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE\nCOMMIT\n";a=1}1' /etc/ufw/before.rules > before.rules
	sudo cat before.rules > /etc/ufw/before.rules
	sudo sed -i 's|DEFAULT_FORWARD_POLICY=.*|DEFAULT_FORWARD_POLICY="ACCEPT"|' /etc/default/ufw
	sudo ufw reload
	sudo ufw allow 2375/tcp

	# start
	sudo service docker start

	# start on boot
	sudo systemctl enable docker
	
	# enable daily image cleanup
	sudo sh -c 'echo "0 6 * * *       docker images -q -a | xargs --no-run-if-empty docker rmi" > /etc/cron.d/docker'
}

install_all()
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
	# install_nginx
	# install_hdparm
	# install_glances
	# install_unzip
	# install_python
	# install_pip
	# install_cifs
	# install_encfs
	# install_acdcli
	# install_unionfs
	# install_gdrive
	# install_rclone
}

usage()
{
	echo "usage: $THIS [utilities]"
	echo "utilities:"
	compgen -A function install_ | sed -r 's|^install_(.+)$| \1|'
	# declare -F | grep "install_" | sed -r 's|^.+ install_(.+)$| \1|'
	exit 1
}

pushd "$SCRATCH" >/dev/null
for util in $*; do
	case $util in
	"all")
		install_all;;
	*)
		eval "install_${util}" || usage;;
	esac
done
popd >/dev/null
