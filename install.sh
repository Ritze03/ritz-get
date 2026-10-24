#!/bin/sh
# ritz-get-spec: 1
# ritz-get's own install.sh: links ~/.local/bin/ritz-get to this clone's ritz-get.
# Usage: ./install.sh --install | --remove [--yes]
set -eu
mode=
for a; do
	case $a in
	--install|--remove) mode=$a ;;
	--yes) ;;
	*) echo "usage: $0 --install | --remove [--yes]" >&2; exit 2 ;;
	esac
done
[ -n "$mode" ] || { echo "usage: $0 --install | --remove [--yes]" >&2; exit 2; }
[ "$(id -u)" -ne 0 ] || { echo "ritz-get: do not run install.sh as root" >&2; exit 1; }
cd "$(dirname "$0")"
here=$(pwd -P)
bin=$HOME/.local/bin
case $mode in
--install)
	command -v git >/dev/null 2>&1 || { echo "missing: git (try: pacman:git dnf:git apt:git)" >&2; exit 3; }
	mkdir -p "$bin"
	ln -sfn "$here/ritz-get" "$bin/ritz-get"
	echo "linked $bin/ritz-get -> $here/ritz-get"
	case ":$PATH:" in *":$bin:"*) ;; *) echo "note: $bin is not in your PATH" ;; esac
	;;
--remove)
	if [ -L "$bin/ritz-get" ] && [ "$(readlink "$bin/ritz-get")" = "$here/ritz-get" ]; then
		rm -f "$bin/ritz-get"
		echo "removed $bin/ritz-get"
	fi
	;;
esac
