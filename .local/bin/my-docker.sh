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

CONFIG_ROOT="/config"
PLEX_ROOT="/plex"
NZBGET_ROOT="/downloads/nzbget"
TRANSMISSION_ROOT="/downloads/transmission"
HYDRA_ROOT="/downloads/hydra"

reset_vars()
{
	IMAGE=
	CONTAINER=
	MOUNT_OPT=
	PORT_OPT=
	ENV_OPT=
	OTHER_OPT=
	UFW=
}

set_common()
{
	MOUNT_OPT="-v /etc/localtime:/etc/localtime:ro -v /dev/rtc:/dev/rtc:ro"
	PORT_OPT=
	ENV_OPT="-e PUID=$(id -u) -e PGID=$(id -g) -e TZ=$(date +%Z)"
	OTHER_OPT="--restart unless-stopped"
	COMMON_OPT="$MOUNT_OPT $PORT_OPT $ENV_OPT $OTHER_OPT"
}

# set_plex()
# {
	# IMAGE="linuxserver/plex"
	# CONTAINER="plex"
	# MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $PLEX_ROOT/tv:/data/tv -v $PLEX_ROOT/movies:/data/movies -v /tmp:/transcode"
	# PORT_OPT=
	# ENV_OPT="-e VERSION=latest"
	# OTHER_OPT="--net=host"
	# UFW="32400"
# }

# https://github.com/plexinc/pms-docker/blob/master/README.md
set_plex()
{
	IMAGE="plexinc/pms-docker"
	CONTAINER="plex"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $PLEX_ROOT/tv:/data/tvshows -v $PLEX_ROOT/movies:/data/movies -v /tmp:/transcode"
	PORT_OPT="-p 32400:32400/tcp \
-p 3005:3005/tcp \
-p 8324:8324/tcp \
-p 32469:32469/tcp \
-p 1900:1900/udp \
-p 32410:32410/udp \
-p 32412:32412/udp \
-p 32413:32413/udp \
-p 32414:32414/udp"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

set_nzbget()
{
	IMAGE="linuxserver/nzbget"
	CONTAINER="nzbget"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $NZBGET_ROOT:/downloads"
	# PORT_OPT="-p 6789:6789"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

set_sonarr()
{
	IMAGE="linuxserver/sonarr"
	CONTAINER="sonarr"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $NZBGET_ROOT:/downloads -v $PLEX_ROOT/tv:/tv"
	# PORT_OPT="-p 8989:8989"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

set_couchpotato()
{
	IMAGE="linuxserver/couchpotato"
	CONTAINER="couchpotato"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $NZBGET_ROOT:/downloads -v $PLEX_ROOT/movies:/movies"
	# PORT_OPT="-p 5050:5050"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

set_plexpy()
{
	IMAGE="linuxserver/plexpy"
	CONTAINER="plexpy"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $CONFIG_ROOT/plex/logs:/logs:ro"
	# PORT_OPT="-p 8181:8181"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

set_transmission()
{
	IMAGE="linuxserver/transmission"
	CONTAINER="transmission"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config -v $TRANSMISSION_ROOT:/downloads -v $TRANSMISSION_ROOT/watch:/watch"
	# PORT_OPT="-p 9091:9091 -p 51413:51413 -p 51413:51413/udp"
	PORT_OPT="-p 51413:51413 -p 51413:51413/udp"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

# https://github.com/firehol/netdata
# https://hub.docker.com/r/titpetric/netdata/
set_netdata()
{
	IMAGE="titpetric/netdata"
	CONTAINER="netdata"
	MOUNT_OPT="-v /var/run/docker.sock:/var/run/docker.sock -v /proc:/host/proc:ro -v /sys:/host/sys:ro -v $NZBGET_ROOT:/nzbget -v $PLEX_ROOT:/plex"
	# PORT_OPT="-p 19999:19999"
	ENV_OPT=
	OTHER_OPT="--cap-add SYS_PTRACE --net mybridge"
	UFW=
}

# https://github.com/kevana/ui-for-docker
set_dockerui()
{
	IMAGE="uifd/ui-for-docker"
	CONTAINER="dockerui"
	MOUNT_OPT="-v /var/run/docker.sock:/var/run/docker.sock"
	# PORT_OPT="-p 9000:9000"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

set_hydra()
{
	IMAGE="linuxserver/hydra"
	CONTAINER="hydra"
	MOUNT_OPT="-v $CONFIG_ROOT/hydra:/config -v $HYDRA_ROOT:/downloads"
	# PORT_OPT="-p 5075:5075"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW=
}

set_nginx()
{
	IMAGE="linuxserver/nginx"
	CONTAINER="nginx"
	MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config"
	PORT_OPT="-p 80:80 -p 443:443"
	ENV_OPT=
	OTHER_OPT="--net mybridge"
	UFW="80/tcp 443/tcp"
}

# set_htpcmanager()
# {
	# IMAGE="linuxserver/htpcmanager"
	# CONTAINER="htpcmanager"
	# MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config"
	# PORT_OPT="-p 8085:8085"
	# ENV_OPT=
	# OTHER_OPT="--link nzbget:nzbget --link sonarr:sonarr --link couchpotato:couchpotato --link transmission:transmission"
	# UFW=
# }

# set_glances()
# {
	# IMAGE="docker.io/nicolargo/glances"
	# CONTAINER="glances"
	# MOUNT_OPT="-v /var/run/docker.sock:/var/run/docker.sock:ro"
	# PORT_OPT="-p 61208-61209:61208-61209"
	# ENV_OPT="-e GLANCES_OPT=-w"
	# OTHER_OPT=
	# UFW=
# }

# set_muximux()
# {
	# IMAGE="linuxserver/muximux"
	# CONTAINER="muximux"
	# MOUNT_OPT="-v $CONFIG_ROOT/$CONTAINER:/config"
	# PORT_OPT="-p 8080:8080"
	# ENV_OPT=
	# OTHER_OPT=
	# UFW=
# }

open_ports()
{
	for port in $UFW
	do
		local cmd="sudo ufw allow $port comment \"$CONTAINER (docker)\""
		echo $cmd
		eval $cmd
	done
}

close_ports()
{
	COUNTER=0
	while [ "$(sudo ufw status | grep "$CONTAINER")" != "" ] && [ $COUNTER -lt 10 ]
	do
		local rule="$(sudo ufw status numbered | grep "$CONTAINER" | sed -rn 's/\[( )?([0-9]{1,2})\].+/\2/p' | head -n1)"
		local cmd="sudo ufw --force delete $rule"
		echo $cmd
		eval $cmd
		let COUNTER=COUNTER+1
	done
}

docker_connect()
{
	local cmd="docker exec -it $CONTAINER /bin/bash"
	echo $cmd
	eval $cmd || exit 1
}

docker_create()
{
	docker_rm || true
	docker network create -d bridge mybridge || true
	
	local cmd="docker create --name $CONTAINER $COMMON_OPT $MOUNT_OPT $PORT_OPT $ENV_OPT $OTHER_OPT $IMAGE"
	echo $cmd
	eval $cmd || exit 1
	
	open_ports
	
	docker_start
}

docker_pull()
{
	local cmd="docker pull $IMAGE"
	echo $cmd
	eval $cmd
	
	docker_create
}

docker_start()
{
	local cmd="docker start $CONTAINER"
	echo $cmd
	eval $cmd || exit 1
}

docker_stop()
{
	local cmd="docker stop $CONTAINER"
	echo $cmd
	eval $cmd
}

docker_restart()
{
	local cmd="docker restart $CONTAINER"
	echo $cmd
	eval $cmd || exit 1
}

docker_rm()
{
	docker_stop || true
	
	local cmd="docker rm $CONTAINER"
	echo $cmd
	eval $cmd || true
	
	close_ports
}

docker_pause()
{
	local cmd="docker pause $CONTAINER"
	echo $cmd
	eval $cmd || exit 1
}

docker_unpause()
{
	local cmd="docker unpause $CONTAINER"
	echo $cmd
	eval $cmd || exit 1
}

docker_list()
{
	# list containers
	local cmd="docker ps -a"
	echo $cmd
	eval $cmd
	
	# list images
	local cmd="docker images"
	echo $cmd
	eval $cmd
	
	# list networks
	local cmd="docker network ls"
	echo $cmd
	eval $cmd
}

docker_clean()
{
	local cmd="docker images -q -a | xargs --no-run-if-empty docker rmi"
	echo $cmd
	eval $cmd || true
}

usage()
{
	echo "usage: $THIS <action> <container>"
	echo "actions:"
	compgen -A function | sed -rn 's|^docker_(.+)$| \1|p'
	echo "containers:"
	echo " all"
	compgen -A function | sed -rn 's|^create_(.+)$| \1|p'
	exit 1
}

# move to scratch
pushd "$SCRATCH" >/dev/null

if [ "${1}" = "list" ]
then
	docker_list
	popd >/dev/null
	exit 0
fi

if [ "${1}" = "clean" ]
then
	docker_clean
	popd >/dev/null
	exit 0
fi

case $2 in
	"all")
		containers="nzbget hydra sonarr couchpotato plex plexpy transmission dockerui netdata nginx";;
	"")
		usage;;
	*)
		containers=$2;;
esac

for cont in $containers; do
	set_common
	reset_vars
	eval "set_${cont}" || usage
	eval "docker_${1}" || usage
done

popd >/dev/null
