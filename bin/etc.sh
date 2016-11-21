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

# if [ "$(id -u)" != "0" ]; then
	# echo "This script must be run as root" 1>&2
	# exit 1
# fi

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

etc_status()
{
	# iterate over files in home/dotfiles/etc (not links)
	for managed_file in $(find ~/dotfiles/etc -mindepth 1 -type f ! -type l $(printf "! -name %s " $SKIP_FILES))
	do
		target_file="$(echo "$managed_file" | sed -nr 's|^.+/dotfiles/etc/(.+)$|/etc/\1|p')"
		
		if [ "$(sudo cat "$target_file")" != "$(cat "$managed_file")" ]; then
			echo "Not Installed: $target_file"
		else
			echo "Installed: $target_file"
		fi
	done
}

etc_install()
{
	# iterate over files in home/dotfiles/etc (not links)
	for managed_file in $(find ~/dotfiles/etc -mindepth 1 -type f ! -type l $(printf "! -name %s " $SKIP_FILES))
	do
		target_file="$(echo "$managed_file" | sed -nr 's|^.+/dotfiles/etc/(.+)$|/etc/\1|p')"
		
		# if [ "$(sudo cat "$target_file")" = "$(cat "$managed_file")" ]; then
			# continue
		# fi
		
		echo "install $target_file from $managed_file?"
		confirm_action || continue
		
		if [ -e "$target_file" ]; then
			echo "$target_file already exists"
			echo "rename it to $target_file.backup?"
			confirm_action || continue
			
			echo "renaming $target_file to $target_file.backup..."
			sudo mv "$target_file" "$target_file.backup"
		fi
		
		echo "installing $managed_file to $target_file..."
		sudo cp "$managed_file"  "$target_file"
		sudo chmod 644 "$target_file"
		sudo chown root:root "$target_file"
	done
}

etc_uninstall()
{
	# iterate over files in home/dotfiles/etc (not links)
	for managed_file in $(find ~/dotfiles/etc -mindepth 1 -type f ! -type l $(printf "! -name %s " $SKIP_FILES))
	do
		target_file="$(echo "$managed_file" | sed -nr 's|^.+/dotfiles/etc/(.+)$|/etc/\1|p')"
		
		if [ -f "$target_file.backup" ]; then
			echo "restoring $target_file.backup..."
			sudo mv "$target_file.backup" "$target_file"
		fi
	done
}

usage()
{
	echo "usage: $THIS [action]"
	echo "actions:"
	compgen -A function | sed -rn 's|^etc_(.+)$| \1|p'
	exit 1
}

# move to home
pushd ~/ >/dev/null

SKIP_FILES='
*.backup
'

eval "etc_${1}" || usage

popd >/dev/null