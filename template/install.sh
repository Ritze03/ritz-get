#!/bin/sh
# Standard install.sh for ritz-get "script" programs. Copy to the repo root, edit the section below.
# ritz-get runs it from inside the clone: ./install.sh --install --yes   (also for every update)
#                                          ./install.sh --remove  --yes   (never touch config/user data)
# Run by hand: ./install.sh --install | --remove [--yes]
set -eu

# ---- per-program section ---------------------------------------------------------------
NAME=myprog
TOOLS="go"                      # tools needed to build, checked with command -v (go cargo npm meson ...)

build() {
	# Go: GOTOOLCHAIN=auto because the pinned Go version is newer than most distro Go packages.
	# It needs any Go >= 1.21 installed and downloads the right toolchain itself.
	GOTOOLCHAIN=auto CGO_ENABLED=0 go build -o "$NAME" .
	# Rust: cargo build --release   (then copy target/release/$NAME)
}

install_files() {
	install -Dm755 "$NAME" "$HOME/.local/bin/$NAME"
	# desktop file, systemd unit, icon ... go here too
}

remove_files() {
	rm -f "$HOME/.local/bin/$NAME"
}
# ----------------------------------------------------------------------------------------

cd "$(dirname "$0")"

missing_tool() {
	f=$(. /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}")
	t=$1
	case " $f " in
	*" arch "*|*" cachyos "*|*" manjaro "*) c="sudo pacman -S"; [ "$t" = cargo ] && t=rust ;;
	*" fedora "*|*" rhel "*) c="sudo dnf install"; [ "$t" = go ] && t=golang ;;
	*" debian "*|*" ubuntu "*) c="sudo apt install"; [ "$t" = go ] && t=golang-go ;;
	*) c="install with your package manager:" ;;
	esac
	echo "$NAME: '$1' is required to build. Try: $c $t" >&2
	exit 1
}

case ${1:-} in
--install)
	for t in $TOOLS; do command -v "$t" >/dev/null 2>&1 || missing_tool "$t"; done
	build
	install_files
	echo "$NAME installed"
	case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "note: ~/.local/bin is not in your PATH" ;; esac
	;;
--remove)
	remove_files
	echo "$NAME removed (config and user data left alone)"
	;;
*) echo "usage: $0 --install | --remove [--yes]" >&2; exit 2 ;;
esac
