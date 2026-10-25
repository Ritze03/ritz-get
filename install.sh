#!/bin/sh
# ritz-get-spec: 1
# ritz-get's own install.sh: links ~/.local/bin/ritz-get to ritz-get's clone in its clone folder
# (config dir=, else ~/.local/share/ritz-get/src), cloning it there first when run from elsewhere.
# Usage: ./install.sh --install | --remove [--yes]
set -eu
NAME=ritz-get
mode=
for a; do
	case $a in
	--install|--remove) [ -z "$mode" ] || { echo "usage: $0 --install | --remove [--yes]" >&2; exit 2; }; mode=$a ;;
	--yes) ;;
	*) echo "usage: $0 --install | --remove [--yes]" >&2; exit 2 ;;
	esac
done
[ -n "$mode" ] || { echo "usage: $0 --install | --remove [--yes]" >&2; exit 2; }
[ "$(id -u)" -ne 0 ] || { echo "ritz-get: do not run install.sh as root" >&2; exit 1; }
# the clone folder, resolved like ritz-get does (before the cd, for a relative dir=)
d=$(sed -n 's/^dir=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/ritz-get/config" 2>/dev/null | tail -n 1)
d=${d:-${XDG_DATA_HOME:-$HOME/.local/share}/ritz-get/src}
case $d in "~") d=$HOME ;; "~/"*) d=$HOME/${d#"~/"} ;; /*) ;; *) d=$PWD/$d ;; esac
while [ "$d" != / ] && [ "${d%/}" != "$d" ]; do d=${d%/}; done
target=$d/$NAME
[ ! -d "$target" ] || target=$(cd "$target" && pwd -P)
cd "$(dirname "$0")"
here=$(pwd -P)
bin=$HOME/.local/bin
case $mode in
--install)
	command -v git >/dev/null 2>&1 || { echo "missing: git (try: pacman:git dnf:git apt:git)" >&2; exit 3; }
	# RITZ_GET_INSTALL_HERE=1: link this checkout as it is (for test harnesses)
	if [ "$here" != "$target" ] && [ -z "${RITZ_GET_INSTALL_HERE:-}" ]; then
		echo "ritz-get installs into $target (where it updates itself); this checkout stays as it is"
		if [ ! -e "$target/.git" ] || [ ! -f "$target/install.sh" ]; then
			[ -z "$(ls -A "$target" 2>/dev/null)" ] || { echo "ritz-get: $target exists and is not a ritz-get clone" >&2; exit 1; }
			url=$(git -C "$here" remote get-url origin 2>/dev/null) || url=https://github.com/Ritze03/ritz-get.git
			mkdir -p "$d" && git clone "$url" "$target"
		fi
		exec "$target/install.sh" "$@"
	fi
	mkdir -p "$bin"
	ln -sfn "$here/ritz-get" "$bin/$NAME"
	echo "linked $bin/$NAME -> $here/ritz-get"
	case ":$PATH:" in *":$bin:"*) ;; *) echo "note: $bin is not in your PATH" ;; esac
	;;
--remove)
	l=$(readlink "$bin/$NAME" 2>/dev/null) || l=
	if [ "$l" = "$here/ritz-get" ] || [ "$l" = "$target/ritz-get" ]; then
		rm -f "$bin/$NAME"
		echo "removed $bin/$NAME"
	fi
	;;
esac
