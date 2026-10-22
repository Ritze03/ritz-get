#!/bin/sh
# ritz-get's own install.sh: links ~/.local/bin/ritz-get to this clone's ritz-get.
# Usage: ./install.sh --install | --remove [--yes]
set -eu
dir=$(cd "$(dirname "$0")" && pwd)
bin=$HOME/.local/bin
case ${1:-} in
--install)
	mkdir -p "$bin"
	chmod +x "$dir/ritz-get"
	ln -sf "$dir/ritz-get" "$bin/ritz-get"
	echo "linked $bin/ritz-get -> $dir/ritz-get"
	case ":$PATH:" in *":$bin:"*) ;; *) echo "note: $bin is not in your PATH" ;; esac
	;;
--remove)
	[ "$(readlink "$bin/ritz-get" 2>/dev/null)" = "$dir/ritz-get" ] && rm "$bin/ritz-get" && echo "removed $bin/ritz-get"
	exit 0
	;;
*) echo "usage: $0 --install | --remove [--yes]" >&2; exit 2 ;;
esac
