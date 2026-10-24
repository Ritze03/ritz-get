#!/bin/sh
# install-ritz-get.sh - the one-time installer for ritz-get. POSIX sh.
#   curl -fsSL https://github.com/Ritze03/ritz-get/releases/latest/download/install-ritz-get.sh | sh
# After this, ritz-get updates itself ("ritz-get update"); this script is never needed again.
# When piped into sh, stdin is this script, so every question is read from /dev/tty.
# With no terminal it uses the defaults: default folder, no PATH edit, no GUI.
# Env: RITZ_GET_DIR (repo folder), RITZ_GET_GIT_BASE (default https://github.com),
#      RITZ_GET_TTY (test hook: read the answers from this file instead of /dev/tty).

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "install-ritz-get: $*" >&2; exit 1; }

# ask QUESTION DEFAULT [NOTTY_DEFAULT]: sets ANS. An empty answer gives DEFAULT; with no terminal NOTTY_DEFAULT (else DEFAULT)
ask() {
	ANS=
	if [ -n "$HAVE_TTY" ]; then
		printf '%s ' "$1" >&2
		read -r ANS <&3 || ANS=
		[ -n "$ANS" ] || ANS=$2
	else ANS=${3:-$2}; fi
}

# normdir D: sets dir to the absolute form of D (~ expanded, no trailing slash)
normdir() {
	dir=$1
	case $dir in "~") dir=$HOME ;; "~/"*) dir=$HOME/${dir#"~/"} ;; /*) ;; *) dir=$PWD/$dir ;; esac
	while [ "$dir" != / ] && [ "${dir%/}" != "$dir" ]; do dir=${dir%/}; done
}

# linked D: true when ~/.local/bin/ritz-get is a symlink into the clone D/ritz-get
linked() {
	lk=$(readlink "$HOME/.local/bin/ritz-get" 2>/dev/null) || return 1
	lp=$(cd "$1/ritz-get" 2>/dev/null && pwd -P)
	case $lk in "$1/ritz-get/"*|"${lp:-$1/ritz-get}/"*) return 0 ;; esac
	return 1
}

# git_hint: the package manager line for git, from os-release; nothing when unknown
git_hint() {
	osr=${RITZ_GET_OS_RELEASE:-/etc/os-release}
	ids= c=
	[ -r "$osr" ] && ids=$( . "$osr" >/dev/null 2>&1; echo " ${ID:-} ${ID_LIKE:-} ")
	case $ids in
	*" arch "*|*" cachyos "*) c="sudo pacman -S git" ;;
	*" fedora "*|*" rhel "*) c="sudo dnf install git" ;;
	*" debian "*|*" ubuntu "*) c="sudo apt install git" ;;
	esac
	[ -z "$c" ] || say "Install it with: $c"
}

main() {
	[ "$(id -u)" -ne 0 ] || die "do not run this as root; it installs into your home folder"
	if ! command -v git >/dev/null 2>&1; then
		echo "missing: git (try: pacman:git dnf:git apt:git)" >&2
		{ say "ritz-get needs git. Install it with your package manager, then run this again."; git_hint; } >&2
		exit 3
	fi
	BASE=${RITZ_GET_GIT_BASE:-https://github.com}
	export GIT_TERMINAL_PROMPT=0
	TTYF=${RITZ_GET_TTY:-/dev/tty} HAVE_TTY=
	if ( : <"$TTYF" ) 2>/dev/null; then exec 3<"$TTYF"; HAVE_TTY=1; fi

	cfg=${XDG_CONFIG_HOME:-$HOME/.config}/ritz-get/config
	def=${XDG_DATA_HOME:-$HOME/.local/share}/ritz-get/src
	cur=
	[ ! -r "$cfg" ] || cur=$(sed -n 's/^dir=//p' "$cfg" | tail -n 1)
	[ -z "$cur" ] || def=$cur
	normdir "${RITZ_GET_DIR:-$def}"
	if [ -e "$dir/ritz-get/.git" ] && linked "$dir"; then
		say "ritz-get is already installed in $dir/ritz-get - use: ritz-get update"
		exit 0
	fi
	if [ -z "${RITZ_GET_DIR:-}" ]; then
		say "ritz-get keeps one git clone per program in a folder."
		ask "Folder for the clones? [$def]" "$def"
		normdir "$ANS"
	fi

	have=
	if [ -e "$dir/ritz-get/.git" ]; then
		linked "$dir" && { say "ritz-get is already installed in $dir/ritz-get - use: ritz-get update"; exit 0; }
		have=1	# cloned, but not linked: the repair path re-runs install.sh
	fi
	[ -n "$have" ] || [ ! -e "$dir/ritz-get" ] || [ -z "$(ls -A "$dir/ritz-get" 2>/dev/null)" ] || die "$dir/ritz-get exists and is not a ritz-get clone"

	std=${XDG_DATA_HOME:-$HOME/.local/share}/ritz-get/src
	if [ "$dir" != "$std" ]; then
		mkdir -p "$(dirname "$cfg")" || die "cannot create $(dirname "$cfg")"
		{ [ ! -r "$cfg" ] || grep -v '^dir=' "$cfg"; printf '%s\n' "dir=$dir"; } >"$cfg.new" && mv -f "$cfg.new" "$cfg" || die "cannot write $cfg"
	fi

	made=
	if [ -z "$have" ]; then
		say "Cloning ritz-get into $dir/ritz-get"
		[ -e "$dir/ritz-get" ] || made=1
		mkdir -p "$dir" || die "cannot create $dir"
		git clone -q "$BASE/Ritze03/ritz-get.git" "$dir/ritz-get" </dev/null || die "could not clone $BASE/Ritze03/ritz-get.git (network?)"
	else say "ritz-get is cloned in $dir/ritz-get but not linked - repairing"; fi
	o=$(mktemp) || die "cannot create a temp file"
	if "$dir/ritz-get/install.sh" --install --yes </dev/null >"$o" 2>&1; then
		grep -v '^note: .* is not in your PATH' "$o"	# the hint below says it
		rm -f "$o"
	else
		cat "$o" >&2; rm -f "$o"
		if [ -z "$have" ]; then	# undo what this run created, so a rerun starts clean
			"$dir/ritz-get/install.sh" --remove --yes </dev/null >/dev/null 2>&1
			if [ -n "$made" ]; then rm -rf "${dir:?}/ritz-get"
			else rm -rf "${dir:?}/ritz-get"/* "$dir/ritz-get"/.[!.]* 2>/dev/null; fi
		fi
		die "ritz-get's install.sh failed"
	fi
	rg=$dir/ritz-get/ritz-get

	bin=$HOME/.local/bin
	case ":$PATH:" in
	*":$bin:"*) ;;
	*)	line='export PATH="$HOME/.local/bin:$PATH"'
		# the file a login shell actually reads: bash skips ~/.profile when ~/.bash_profile or ~/.bash_login exists
		case ${SHELL:-} in
		*/zsh) prof=$HOME/.zprofile ;;
		*)	if [ -e "$HOME/.bash_profile" ]; then prof=$HOME/.bash_profile
			elif [ -e "$HOME/.bash_login" ]; then prof=$HOME/.bash_login
			else prof=$HOME/.profile; fi ;;
		esac
		pn="~/${prof##*/}"
		say ""
		say "$bin is not in your PATH. Add this line to $pn:"
		say "  $line"
		ask "Add it to $pn for you now? [y/N]" n
		case $ANS in
		y|Y|yes)
			if grep -qsF "$line" "$prof"; then say "$pn already has it."
			else printf '\n# added by install-ritz-get.sh\n%s\n' "$line" >>"$prof" && say "Added to $pn. Log out and in again, or run: . $pn"; fi ;;
		esac ;;
	esac

	say ""
	say "ritz-get is installed. Try: ritz-get list"
	if "$rg" list --offline --porcelain </dev/null | awk -F'\t' '$1 == "E" && $3 == "ritz-get-gui" { f = 1 } END { exit !f }'; then
		ask "Also install the GUI? [Y/n]" y n
		case $ANS in y|Y|yes|Yes) install_gui "$rg" ;; esac
	fi
	return 0
}

# install_gui RG: install ritz-get-gui and its start-menu shortcut. Missing build tools are not a failure.
install_gui() {
	out=$(mktemp) || return 0
	{ "$1" install ritz-get-gui </dev/null; echo $? >"$out.rc"; } | tee "$out"
	rc=$(cat "$out.rc" 2>/dev/null || echo 1)
	case $rc in
	0)	"$1" shortcut ritz-get-gui </dev/null || true
		say ""
		say "Open ritz-get-gui from your app menu." ;;
	3)	say ""
		say "ritz-get is installed; the GUI needs these first:"
		grep -E '^(deps|missing):' "$out" || true
		say "Then run: ritz-get install ritz-get-gui" ;;
	*)	rm -f "$out" "$out.rc"
		die "the GUI install failed (ritz-get itself is installed). Try again with: ritz-get install ritz-get-gui" ;;
	esac
	rm -f "$out" "$out.rc"
}

main "$@"
