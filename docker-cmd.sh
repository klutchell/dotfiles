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

if [ "$(id -u)" = "0" ]; then
	echo "This script should not be run as root" 1>&2
	exit 1
fi

CONFIG_ROOT="/opt"
PLEX_ROOT="/data/plex"
NZBGET_ROOT="/data/nzbget"
TRANSMISSION_ROOT="/data/transmission"
HYDRA_ROOT="/data/hydra"

COMMON_OPT="-e PUID=$(id -u) -e PGID=$(id -g) -e TZ=$(date +%Z) -v /etc/localtime:/etc/localtime:ro -v /dev/rtc:/dev/rtc:ro --restart unless-stopped"

reset_vars()
{
	IMAGE=
	CONTAINER=
	MOUNT_OPT=
	PORT_OPT=
	OTHER_OPT=
	UFW=
}

set_plex()
{
	IMAGE="linuxserver/plex"
	CONTAINER="plex"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $PLEX_ROOT/tv:/data/tv -v $PLEX_ROOT/movies:/data/movies -v /tmp:/transcode"
	PORT_OPT=
	OTHER_OPT="--net=host -e VERSION=latest"
	UFW="32400"
}

set_nzbget()
{
	IMAGE="linuxserver/nzbget"
	CONTAINER="nzbget"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $NZBGET_ROOT:/downloads"
	PORT_OPT="-p 6789:6789"
	OTHER_OPT=
	UFW=
}

set_sonarr()
{
	IMAGE="linuxserver/sonarr"
	CONTAINER="sonarr"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $NZBGET_ROOT:/downloads -v $PLEX_ROOT/tv:/tv"
	PORT_OPT="-p 8989:8989"
	OTHER_OPT="--link nzbget:nzbget"
	UFW=
}

set_couchpotato()
{
	IMAGE="linuxserver/couchpotato"
	CONTAINER="couchpotato"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $NZBGET_ROOT:/downloads -v $PLEX_ROOT/movies:/movies"
	PORT_OPT="-p 5050:5050"
	OTHER_OPT="--link nzbget:nzbget"
	UFW=
}

set_plexpy()
{
	IMAGE="linuxserver/plexpy"
	CONTAINER="plexpy"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $CONFIG_ROOT/plex/logs:/logs:ro"
	PORT_OPT="-p 8181:8181"
	OTHER_OPT=
	UFW=
}

set_transmission()
{
	IMAGE="linuxserver/transmission"
	CONTAINER="transmission"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $TRANSMISSION_ROOT:/downloads -v $TRANSMISSION_ROOT/watch:/watch"
	PORT_OPT="-p 9091:9091 -p 51413:51413 -p 51413:51413/udp"
	OTHER_OPT=
	UFW="51413"
}

set_nginx()
{
	IMAGE="linuxserver/nginx"
	CONTAINER="nginx"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config"
	PORT_OPT="-p 80:80 -p 443:443"
	OTHER_OPT="--link nzbget:nzbget --link sonarr:sonarr --link couchpotato:couchpotato --link plexpy:plexpy --link transmission:transmission --link glances:glances"
	UFW="80/tcp 443/tcp"
}

# set_nzedb()
# {
	# # IMAGE="bsmith1988/nzedb-docker"
	# IMAGE="nzedb/master"
	# CONTAINER="nzedb"
	# # MOUNT_OPT="-v $CONFIG_ROOT/nzedb:/var/www/nZEDb"
	# PORT_OPT="-p 8800:8800"
	# OTHER_OPT=
	# UFW="8800"
# }

# set_hydra()
# {
	# IMAGE="linuxserver/hydra"
	# CONTAINER="hydra"
	# MOUNT_OPT="-v $CONFIG_ROOT/hydra:/config -v $HYDRA_ROOT:/downloads"
	# PORT_OPT="-p 5075:5075"
	# OTHER_OPT=
	# UFW=
# }

# set_muximux()
# {
	# IMAGE="linuxserver/muximux"
	# CONTAINER="muximux"
	# MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config"
	# PORT_OPT="-p 8080:8080"
	# OTHER_OPT=
	# UFW=
# }

# set_htpcmanager()
# {
	# IMAGE="linuxserver/htpcmanager"
	# CONTAINER="htpcmanager"
	# MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config"
	# PORT_OPT="-p 8085:8085"
	# OTHER_OPT="---link nzbget:nzbget --link sonarr:sonarr --link couchpotato:couchpotato --link plexpy:plexpy --link transmission:transmission"
	# UFW=
# }

set_glances()
{
	IMAGE="docker.io/nicolargo/glances"
	CONTAINER="glances"
	MOUNT_OPT="-v /var/run/docker.sock:/var/run/docker.sock:ro"
	PORT_OPT="-p 61208-61209:61208-61209"
	OTHER_OPT="-e GLANCES_OPT=-w"
	UFW=
}

open_ports()
{
	for port in $UFW
	do
		echo "ufw allow $port"
		sudo ufw allow $port
	done
}

close_ports()
{
	for port in $UFW
	do
		echo "ufw --force delete allow $port"
		sudo ufw --force delete allow $port
	done
}

docker_create()
{
	docker_delete || true
	
	echo "docker create --name $CONTAINER $MOUNT_OPT $PORT_OPT $OTHER_OPT $COMMON_OPT $IMAGE"
	docker create --name $CONTAINER $MOUNT_OPT $PORT_OPT $OTHER_OPT $COMMON_OPT $IMAGE || exit 1
	
	open_ports
	
	docker_start
}

docker_update()
{
	echo "docker pull $IMAGE"
	docker pull "$IMAGE"
	
	docker_create
}

docker_start()
{
	echo "docker start $CONTAINER"
	docker start $CONTAINER
}

docker_stop()
{
	echo "docker stop $CONTAINER"
	docker stop $CONTAINER
}

docker_restart()
{
	echo "docker restart $CONTAINER"
	docker restart $CONTAINER
}

docker_delete()
{
	docker_stop || true
	
	echo "docker rm $CONTAINER"
	docker rm $CONTAINER
	
	close_ports
}

docker_pause()
{
	echo "docker pause $CONTAINER"
	docker pause $CONTAINER
}

docker_unpause()
{
	echo "docker unpause $CONTAINER"
	docker unpause $CONTAINER
}

usage()
{
	echo "usage: $THIS <action> <container>"
	echo "actions:"
	compgen -A function docker_ | sed -r 's|^docker_(.+)$| \1|'
	echo "containers:"
	echo " all"
	compgen -A function create_ | sed -r 's|^create_(.+)$| \1|'
	exit 1
}

case $2 in
	"all")
		containers="nzbget sonarr couchpotato plex plexpy transmission glances nginx";;
	"")
		usage;;
	*)
		containers=$2;;
esac

# move to scratch
pushd "$SCRATCH" >/dev/null

for cont in $containers; do
	echo
	reset_vars
	eval "set_${cont}" || usage
	eval "docker_${1}" || usage
done

# list containers
echo
docker ps -a

# list images
echo
docker images

popd >/dev/null
