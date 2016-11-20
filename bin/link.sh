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

# move to home
pushd ~ >/dev/null

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

# print current links
for file in $(find ~ -maxdepth 1 -mindepth 1 -name ".*" -exec basename {} \;)
do
	[ -n "$(readlink $file)" ] && echo "$file --> $(readlink $file)"
	[ -n "$(readlink $file)" ] || echo "$file"
done

# iterate over files in home/dotfiles
for file in $(find ~/dotfiles -maxdepth 1 -mindepth 1 ! -type l ! -name "*.*" -exec basename {} \;)
do
	file="${file#"."}"
	home_file=".$file"
	dot_file="dotfiles/$file"
	
	echo "link $home_file from dotfiles?"
	confirm_action || continue
	
	if [ -L "$home_file" ] && [ "$(readlink "$home_file")" = "$dot_file" ]; then
		echo "removing existing link..."
		rm "$home_file"
	fi
	
	if [ -e "$home_file" ]; then
		echo "$home_file already exists"
		echo "rename it to $home_file.backup?"
		confirm_action || continue
		
		echo "renaming $home_file to $home_file.backup..."
		mv "$home_file" "$home_file.backup"
	fi
	
	echo "linking $home_file to $dot_file..."
	ln -s "$dot_file" "$home_file"
done

# print current links
for file in $(find ~ -maxdepth 1 -mindepth 1 -name ".*" -exec basename {} \;)
do
	[ -n "$(readlink $file)" ] && echo "$file --> $(readlink $file)"
	[ -n "$(readlink $file)" ] || echo "$file"
done

popd >/dev/null