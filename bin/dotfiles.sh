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

dotfiles_add()
{
	# iterate over files/folders in home
	for file in $(find ~ -maxdepth 1 -mindepth 1 ! -type l -exec basename {} \;)
	do
		[ "$file" = "dotfiles" ] && continue
		dot_file="dotfiles/$file"
		
		echo "add $file to dotfiles?"
		confirm_action || continue
		
		if [ -e "$dot_file" ]; then
			echo "this will replace the existing $dot_file"
			confirm_action || continue
			
			echo "removing $dot_file..."
			rm -rf "$dot_file"
		fi
		
		echo "moving $file to $dot_file..."
		mv "$file" "$dot_file"
		
		echo "linking $file to $dot_file..."
		ln -s "$dot_file" "$file"
	done
}

dotfiles_install()
{
	# iterate over files/folders in home/dotfiles
	for file in $(find ~/dotfiles -maxdepth 1 -mindepth 1 ! -type l -exec basename {} \;)
	do
		[ "$file" = "README.md" ] && continue
		dot_file="dotfiles/$file"
		
		echo "install $file from dotfiles?"
		confirm_action || continue
		
		if [ -L "$file" ] && [ "$(readlink "$file")" = "$dot_file" ]; then
			echo "removing existing link..."
			rm "$file"
		fi
		
		if [ -e "$file" ]; then
			echo "$file already exists"
			echo "rename it to $file.backup?"
			confirm_action || continue
			
			echo "renaming $file to $file.backup..."
			mv "$file" "$file.backup"
		fi
		
		echo "linking $file to $dot_file..."
		ln -s "$dot_file" "$file"
	done
}

dotfiles_uninstall()
{
	# iterate over files/folders in home/dotfiles
	for file in $(find ~/dotfiles -maxdepth 1 -mindepth 1 ! -type l -exec basename {} \;)
	do
		[ "$file" = "README.md" ] && continue
		dot_file="dotfiles/$file"
		
		echo "remove $file from dotfiles?"
		confirm_action || continue
		
		if [ -L "$file" ] && [ "$(readlink "$file")" = "$dot_file" ]; then
			echo "removing existing link..."
			rm "$file"
		fi
		
		if [ -e "$file" ]; then
			echo "$file already exists"
			echo "rename it to $file.backup?"
			confirm_action || continue
			
			echo "renaming $file to $file.backup..."
			mv "$file" "$file.backup"
		fi
		
		echo "moving $dot_file to $file..."
		mv "$dot_file" "$file"
	done
}

usage()
{
	echo "usage: $THIS [action]"
	echo "actions:"
	compgen -A function | sed -rn 's|^dotfiles_(.+)$| \1|p'
	exit 1
}

dotfiles_status()
{
	# print current links
	for file in $(find ~ -maxdepth 1 -mindepth 1 -exec basename {} \;)
	do
		[ -n "$(readlink $file)" ] && echo "$file --> $(readlink $file)"
		[ -n "$(readlink $file)" ] || echo "$file"
	done
}

# move to home
pushd ~/ >/dev/null

dotfiles_status

eval "dotfiles_${1}" || usage

dotfiles_status

popd >/dev/null