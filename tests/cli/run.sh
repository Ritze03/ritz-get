#!/bin/sh
# CLI tests for ritz-get: sh tests/cli/run.sh
# Everything happens in a throwaway HOME against local bare repos (file://); no network, no real HOME.
# Prints "PASS name" / "FAIL name: why", then "ALL PASS" or "N FAILED"; exit status follows.
ROOT=$(cd "$(dirname "$0")/../.." && pwd -P)
RG=$ROOT/ritz-get
for c in git flock timeout awk setsid; do command -v "$c" >/dev/null 2>&1 || { echo "FAIL setup: $c not installed"; exit 1; }; done
T=$(mktemp -d "${TMPDIR:-/tmp}/ritz-get-test.XXXXXX") || exit 1
HOLD=
trap '[ -z "$HOLD" ] || kill "$HOLD" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/home" "$T/run" "$T/tmp" "$T/remote/t" "$T/work"
HOME=$T/home XDG_CONFIG_HOME=$T/home/.config XDG_DATA_HOME=$T/home/.local/share XDG_CACHE_HOME=$T/home/.cache
XDG_RUNTIME_DIR=$T/run TMPDIR=$T/tmp LC_ALL=C
RITZ_GET_GIT_BASE=file://$T/remote RITZ_GET_MANIFEST=$T/programs RITZ_GET_GUI=1
GIT_CONFIG_GLOBAL=$T/home/.gitconfig GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file
export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR TMPDIR LC_ALL RITZ_GET_GIT_BASE \
	RITZ_GET_MANIFEST RITZ_GET_GUI GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_ALLOW_PROTOCOL
unset RITZ_GET_SUDO RITZ_GET_TIMEOUT RITZ_GET_OS_RELEASE RITZ_GET_SELF_UPDATED
printf '[user]\n\tname = t\n\temail = t@t\n[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n[protocol "file"]\n\tallow = always\n' >"$HOME/.gitconfig"
SRC=$XDG_DATA_HOME/ritz-get/src
LOCK=$XDG_RUNTIME_DIR/ritz-get.lock
P=0 F=0

# ---- helpers ---------------------------------------------------------------------------
pass() { echo "PASS $1"; P=$((P + 1)); }
bad() { echo "FAIL $1: $2"; F=$((F + 1)); }
done_run() { RC=$?; cat "$T/out" "$T/err" >"$T/all"; }
rg() { sh "$RG" "$@" >"$T/out" 2>"$T/err" </dev/null; done_run; }
rge() { e=$1; shift; env "$e" sh "$RG" "$@" >"$T/out" 2>"$T/err" </dev/null; done_run; }	# rge VAR=val ARGS...
rgi() { i=$1; shift; printf '%s\n' "$i" | sh "$RG" "$@" >"$T/out" 2>"$T/err"; done_run; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1" "expected [$2] got [$3]"; fi; }
rc() { eq "$1: exit $2" "$2" "$RC"; }
has() { if grep -qF -- "$2" "$T/all"; then pass "$1"; else bad "$1" "missing [$2] in: $(head -c 400 "$T/all" | tr '\n' '|')"; fi; }
lacks() { if grep -qF -- "$2" "$T/all"; then bad "$1" "unexpected [$2]"; else pass "$1"; fi; }
exists() { if [ -e "$2" ]; then pass "$1"; else bad "$1" "$2 missing"; fi; }
gone() { if [ -e "$2" ]; then bad "$1" "$2 still exists"; else pass "$1"; fi; }
fld() { awk -F'\t' -v n="$1" -v i="$2" '$1 == "E" && $3 == n { print $i }' "$T/out"; }	# porcelain field
row_is() { eq "$1" "$(printf "$3")" "$(awk -F'\t' -v n="$2" '$1 == "E" && $3 == n' "$T/out")"; }
match() { if printf '%s' "$3" | grep -Eq "$2"; then pass "$1"; else bad "$1" "[$3] !~ $2"; fi; }
clone() { echo "$SRC/$1"; }
sha() { git -C "$SRC/$1" rev-parse HEAD; }

# mkrepo NAME: bare repo remote/t/NAME.git with a spec-style install.sh; work tree work/NAME
cat >"$T/install.tpl" <<'EOF'
#!/bin/sh
# ritz-get-spec: @SPEC@
set -eu
cd "$(dirname "$0")"
bin=$HOME/.local/bin
case ${1:-} in
--install)
	case $(cat mode) in
	missing) echo "missing: gcc (try: pacman:gcc dnf:gcc apt:build-essential)" >&2
		echo "missing: pkgx (try: pacman:p1,p2 dnf:p3 apt:p4,p5)" >&2; exit 3 ;;
	missing2) echo "missing: gcc (try: pacman:gcc dnf:gcc apt:build-essential)" >&2
		echo "missing: noapt (try: pacman:nap)" >&2; exit 3 ;;
	root) echo "needs root: run ritz-get install @NAME@ in a terminal" >&2; exit 4 ;;
	fail) echo boom >&2; exit 1 ;;
	slow) echo $$ >"$HOME/slow.pid"; sleep 30 ;;
	noisy) echo "compiling @NAME@..."; echo "note: start it with: @NAME@ --daemon"
		echo "restart: @NAME@ to use the new version" >&2; echo "setup: do the thing"; echo done ;;
	loud) i=1; while [ $i -le 20 ]; do echo "step $i"; i=$((i + 1)); done; echo "oops" >&2; exit 1 ;;
	esac
	mkdir -p "$bin"
	ln -sfn "$(pwd -P)/@NAME@" "$bin/@NAME@"
	echo "@NAME@ installed spec=$RITZ_GET_SPEC sudo=[$RITZ_GET_SUDO] term=$TERM nocolor=$NO_COLOR"
	;;
--remove)
	if [ "$(readlink "$bin/@NAME@" 2>/dev/null)" = "$(pwd -P)/@NAME@" ]; then rm -f "$bin/@NAME@"; fi
	echo "@NAME@" >>"$HOME/removed.log"
	echo "@NAME@ removed"
	;;
*) exit 2 ;;
esac
EOF
mkrepo() { # NAME [SPEC] [MODE]
	w=$T/work/$1; mkdir -p "$w"
	sed "s/@NAME@/$1/g; s/@SPEC@/${2:-1}/" "$T/install.tpl" >"$w/install.sh"
	printf '#!/bin/sh\necho %s\n' "$1" >"$w/$1"
	chmod +x "$w/install.sh" "$w/$1"
	echo "${3:-ok}" >"$w/mode"
	printf 'build/\n' >"$w/.gitignore"
	(cd "$w" && git init -q -b main && git add -A && git commit -q -m v0 &&
		git clone -q --bare . "$T/remote/t/$1.git" && git remote add origin "$T/remote/t/$1.git" &&
		git fetch -q origin && git branch -q -u origin/main)
}
# newcommit NAME [MODE]: a new commit on main of the remote (optionally switching the install mode)
newcommit() {
	(cd "$T/work/$1" && git checkout -q main && n=$(($(cat ver 2>/dev/null || echo 0) + 1)) && echo "$n" >ver &&
		{ [ -z "${2:-}" ] || echo "$2" >mode; } && git add -A && git commit -q -m "v$n" && git push -q origin main)
}

mkrepo alpha; mkrepo beta; mkrepo gamma 1 missing; mkrepo theta 1 missing2; mkrepo delta 1 root
mkrepo eps 1 fail; mkrepo zeta 1 slow; mkrepo eta 2
# ritz-get itself: the real script and install.sh
mkdir -p "$T/work/ritz-get"
cp "$ROOT/ritz-get" "$ROOT/install.sh" "$T/work/ritz-get/"
mkdir -p "$T/work/ritz-get/icons"; printf '\211PNG\r\n\032\n' >"$T/work/ritz-get/icons/site.png"
(cd "$T/work/ritz-get" && git init -q -b main && git add -A && git commit -q -m v0 &&
	git clone -q --bare . "$T/remote/t/ritz-get.git" && git remote add origin "$T/remote/t/ritz-get.git" &&
	git fetch -q origin && git branch -q -u origin/main)
(cd "$T/work/beta" && git checkout -q -b dev && echo d >devfile && git add -A && git commit -q -m dev &&
	git push -q origin dev && git checkout -q main)

# fixtures for shortcuts: repos that ship NAME.desktop (and icon.png)
mkrepo shorty; mkrepo shorty2
cat >"$T/work/shorty/shorty.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Shorty Raw
Exec=shorty --flag %U
Icon=shorty-own-icon
Categories=Utility;

[Desktop Action act]
Name=Act
Exec=shorty --act
EOF
printf '\211PNG\r\n\032\n' >"$T/work/shorty/icon.png"
cat >"$T/work/shorty2/shorty2.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Raw Two
Exec="/opt/two words/run" -x %f
Icon=foo
EOF
for r in shorty shorty2; do (cd "$T/work/$r" && git add -A && git commit -q -m desktop && git push -q origin main); done
# the GUI repo and an installer remote (Ritze03/ritz-get.git next to the t/ repos)
mkrepo ritz-get-gui
printf '[Desktop Entry]\nType=Application\nName=GUI\nExec=ritz-get-gui\n' >"$T/work/ritz-get-gui/ritz-get-gui.desktop"
(cd "$T/work/ritz-get-gui" && git add -A && git commit -q -m desktop && git push -q origin main)
mkdir -p "$T/remote/Ritze03" "$T/work/rgi"
cp "$ROOT/ritz-get" "$ROOT/install.sh" "$ROOT/programs" "$T/work/rgi/"
sed "s#^ritz-get-gui Ritze03/ritz-get-gui \"[^\"]*\"#ritz-get-gui t/ritz-get-gui \"The GUI\"#" "$ROOT/programs" >"$T/work/rgi/programs"
(cd "$T/work/rgi" && git init -q -b main && git add -A && git commit -q -m v0 && git clone -q --bare . "$T/remote/Ritze03/ritz-get.git")
# xdg-open stub
mkdir -p "$T/bin"
printf '#!/bin/sh\necho "$@" >>"%s"\n' "$T/xdg.log" >"$T/bin/xdg-open"; chmod +x "$T/bin/xdg-open"

cat >"$T/programs" <<'EOF'
# test manifest
alpha t/alpha "Alpha program"
  title: Alpha Tool
  setup: Open the app and press go
  setup: Docs: https://example.com/x#y

[Helpers]
  # indented comment is ignored
ritz-get t/ritz-get "ritz-get itself"
beta t/beta "Beta helper"
gamma t/gamma "Needs tools"
theta t/theta "Needs other tools"
delta t/delta "Needs root"
eps t/eps "Fails"
zeta t/zeta "Slow"
eta t/eta "Spec 2"
ghost t/ghost "Does not exist"
shorty t/shorty "Has a shortcut"
  title: Shorty Title
shorty2 t/shorty2 "Shortcut without categories"

[Websites]
site https://example.com/page#frag "A site"
  title: Cool Site
badurl https://x.example/a'b "Quote in the URL"
EOF
printf 'ID=cachyos\nID_LIKE=arch\n' >"$T/os-arch"; printf 'ID=fedora\n' >"$T/os-fedora"
printf 'ID=ubuntu\nID_LIKE="debian"\n' >"$T/os-ubuntu"; printf 'ID=plan9\n' >"$T/os-other"

# ---- usage -----------------------------------------------------------------------------
rg help; rc help 0; has "help text" "usage: ritz-get"
rg bogus; rc "unknown command" 2
rg install; rc "install without name" 2
rg list --nonsense; rc "unknown option" 2

# ---- list: manifest grammar, porcelain, offline ----------------------------------------
rg list --offline --porcelain; rc "list --offline --porcelain" 0
eq "porcelain header" "#porcelain 1" "$(sed -n 1p "$T/out")"
eq "porcelain online flag" "#online 0" "$(sed -n 2p "$T/out")"
row_is "row: alpha (title, desc, default section)" alpha 'E\tSoftware\talpha\tAlpha Tool\tprogram\tt/alpha\toffline\t-\t0\t-\t-\t-\t-\t-\t-\tAlpha program\t-'
row_is "row: beta (section Helpers, title = name)" beta 'E\tHelpers\tbeta\tbeta\tprogram\tt/beta\toffline\t-\t0\t-\t-\t-\t-\t-\t-\tBeta helper\t-'
row_is "row: website (URL with #)" site 'E\tWebsites\tsite\tCool Site\twebsite\thttps://example.com/page#frag\twebsite\t-\t0\t-\t-\t-\t-\t-\t-\tA site\toff'
eq "setup lines follow their entry" "$(printf 'S\talpha\tOpen the app and press go\nS\talpha\tDocs: https://example.com/x#y')" "$(grep '^S' "$T/out")"
eq "offline: nothing hidden" 0 "$(grep -c '^#hidden' "$T/out")"
eq "no tab inside fields" 0 "$(awk -F'\t' '$1 == "E" && NF != 17' "$T/out" | wc -l | tr -d ' ')"

rg list --porcelain; rc "list --porcelain (online)" 0
eq "online flag" "#online 1" "$(sed -n 2p "$T/out")"
eq "available" available "$(fld alpha 7)"
match "latest of a not-installed program is a short sha" '^[0-9a-f]{7}$' "$(fld alpha 12)"
eq "unreachable repo hidden" "" "$(fld ghost 7)"
eq "hidden footer" "#hidden 1" "$(tail -n 1 "$T/out")"
rg list --porcelain --all
eq "--all shows unreachable" unreachable "$(fld ghost 7)"
eq "--all: no hidden footer" 0 "$(grep -c '^#hidden' "$T/out")"
rge RITZ_GET_GIT_BASE=file://$T/nowhere list --porcelain
eq "ritz-get repo unreachable = offline flag" "#online 0" "$(sed -n 2p "$T/out")"
eq "offline: not-installed state" offline "$(fld alpha 7)"
eq "offline: nothing hidden" "offline 0" "$(fld ghost 7) $(grep -c '^#hidden' "$T/out")"
rg list; rc "human list" 0
has "human: section header" "Helpers"
has "human: title shown" "Alpha Tool"
has "human: description shown" "Alpha program"
has "human: hidden footer" "1 program(s) hidden (no access)"
rg list alpha
has "list NAME: setup lines" "Additional steps required:"
has "list NAME: setup text" "Docs: https://example.com/x#y"
rg list nope; rc "list unknown name" 1; has "list unknown name text" "unknown program: nope"

# ---- install, repair, failed first install ---------------------------------------------
rg install alpha; rc "install alpha" 0
has "install: setup steps printed" "Additional steps required:"
has "install: env for install.sh" "spec=1 sudo=[] term=dumb nocolor=1"
exists "install: link created" "$HOME/.local/bin/alpha"
exists "install: clone exists" "$SRC/alpha/.git"
rg list --porcelain alpha
eq "installed state" installed "$(fld alpha 7)"
eq "installed status" current "$(fld alpha 8)"
eq "held 0" 0 "$(fld alpha 9)"
eq "branch" main "$(fld alpha 10)"
match "installed version = date + sha" '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9a-f]{7,}$' "$(fld alpha 11)"
eq "latest = installed when current" "$(fld alpha 11)" "$(fld alpha 12)"
eq "behind/dirty/ahead" "0 0 0" "$(fld alpha 13) $(fld alpha 14) $(fld alpha 15)"
rg list --porcelain --offline alpha
eq "offline: status unknown" unknown "$(fld alpha 8)"
eq "offline: latest/behind unknown, dirty known" "- - 0 0" "$(fld alpha 12) $(fld alpha 13) $(fld alpha 14) $(fld alpha 15)"
rm "$HOME/.local/bin/alpha"
rge RITZ_GET_SUDO=pkexec install alpha; rc "repair (install on installed)" 0
has "repair message" "repairing"
has "RITZ_GET_SUDO passes through" "sudo=[pkexec]"
exists "repair re-creates the link" "$HOME/.local/bin/alpha"
rg install alpha --branch dev; rc "install --branch on installed" 1; has "points to switch" "ritz-get switch alpha dev"

rg install eps; rc "failed first install" 1
has "failure trailer: first install says nothing was installed" "FAILED — nothing was installed"
lacks "failure trailer: first install does not claim an unchanged version" "installed version is unchanged"
gone "failed first install deletes the clone ritz-get created" "$SRC/eps"
has "failed first install ran --remove" "eps"; eq "remove log" eps "$(cat "$HOME/removed.log")"
mkdir -p "$SRC/eps"; echo x >"$SRC/eps/keep"
rg install eps; rc "install into a pre-existing folder" 1
exists "pre-existing folder survives" "$SRC/eps/keep"
rm -rf "$SRC/eps"

rg install delta; rc "exit 4 passes through" 4; has "needs root line" "needs root: run ritz-get install delta"
rge RITZ_GET_TIMEOUT=2 install zeta; rc "timeout" 1
env -u RITZ_GET_GUI RITZ_GET_TIMEOUT=2 sh "$RG" install zeta >"$T/out" 2>"$T/err" </dev/null; done_run; rc "quiet: timeout" 1
has "quiet: timeout names the log" "zeta: FAILED (timed out after 2s) — build log: $XDG_CACHE_HOME/ritz-get/logs/zeta.log"
has "timeout message" "timed out after 2s"; gone "timeout: clone removed" "$SRC/zeta"
rg install eta; rc "spec marker 2" 1; has "spec marker message" "needs a newer ritz-get"; gone "spec 2: clone removed" "$SRC/eta"
rg install site; rc "install a website" 1

# ---- exit 3: aggregated deps line ------------------------------------------------------
rge RITZ_GET_OS_RELEASE=$T/os-arch install gamma theta; rc "missing tools" 3
has "per-program status" "gamma: FAILED (needs: gcc, pkgx)"
eq "pacman deps line (merged, deduped)" "deps: sudo pacman -S --needed gcc nap p1 p2" "$(grep '^deps:' "$T/out")"
eq "one deps line" 1 "$(grep -c '^deps:' "$T/out")"
gone "missing deps: clone removed" "$SRC/gamma"
rge RITZ_GET_OS_RELEASE=$T/os-fedora install gamma theta
eq "dnf deps line" "deps: sudo dnf install gcc p3" "$(grep '^deps:' "$T/out")"
has "unmappable line stays raw" "missing: noapt (try: pacman:nap)"
rge RITZ_GET_OS_RELEASE=$T/os-ubuntu install gamma
eq "apt deps line (ID_LIKE)" "deps: sudo apt install build-essential p4 p5" "$(grep '^deps:' "$T/out")"
rge RITZ_GET_OS_RELEASE=$T/os-other install gamma; rc "unknown distro" 3
lacks "unknown distro: no deps line" "deps:"; has "unknown distro: raw missing lines" "missing: pkgx (try: pacman:p1,p2 dnf:p3 apt:p4,p5)"

# ---- update ----------------------------------------------------------------------------
rg install beta ritz-get; rc "install beta + ritz-get" 0
rg update --yes; rc "update, nothing new" 0
has "up to date line" "alpha: up to date"
has "summary" "0 updated, 0 skipped, 0 failed"
eq "last-run content" "0 updated, 0 skipped, 0 failed" "$(sed 's/^[^ ]* //' "$XDG_CACHE_HOME/ritz-get/last-run")"
newcommit alpha
rg update --yes; rc "update alpha" 0
has "updated line" "alpha: updated"; has "updated shows A -> B" " -> "
has "summary counts" "1 updated, 0 skipped, 0 failed"
newcommit alpha
rg update; rc "update without --yes (no tty) aborts" 0; has "aborted" "aborted"
eq "abort left alpha behind" 1 "$(git -C "$SRC/alpha" rev-list --count 'HEAD..@{u}')"
rg update --yes >/dev/null

rg hold beta; rc "hold" 0
eq "hold flag in the clone's git config" true "$(git -C "$SRC/beta" config --get ritz-get.hold)"
newcommit beta
rg update --yes; rc "update-all skips held" 0
has "held line" "beta: held (ritz-get unhold beta)"; has "held counts as skipped" "0 updated, 1 skipped, 0 failed"
rg list --porcelain
eq "held in porcelain" "1 behind" "$(fld beta 9) $(fld beta 8)"
rg update beta --yes; rc "update NAME updates a held program" 0; has "held program updated by name" "beta: updated"
rg unhold beta; rc "unhold" 0
eq "unhold clears it" 0 "$(git -C "$SRC/beta" config --get-all ritz-get.hold | wc -l | tr -d ' ')"
rg hold nope; rc "hold unknown" 1

# ---- refuse to run as root: a fake `id` earlier in PATH says uid 0 ----
mkdir -p "$T/fakeid"; printf '#!/bin/sh\n[ "$1" = -u ] && echo 0 || exec /usr/bin/id "$@"\n' >"$T/fakeid/id"; chmod +x "$T/fakeid/id"
rge PATH="$T/fakeid:$PATH" install alpha; rc "root: install refused" 2
has "root: message" "ritz-get: do not run with sudo; it asks for root itself when needed"
rge PATH="$T/fakeid:$PATH" remove alpha; rc "root: remove refused" 2
rge PATH="$T/fakeid:$PATH" help; rc "root: help is still allowed" 0
has "root: help prints usage" "usage: ritz-get"

mv "$T/remote/t/beta.git" "$T/remote/t/beta.gone"
rg list --porcelain; eq "fetch-failed keeps installed visible" "installed fetch-failed" "$(fld beta 7) $(fld beta 8)"
rg update beta --yes; rc "update with failing fetch" 1; has "fetch failed message" "beta: FAILED (fetch failed)"
mv "$T/remote/t/beta.gone" "$T/remote/t/beta.git"

before=$(sha alpha)
newcommit alpha fail
rg update --yes; rc "failing update" 1
has "FAILED line" "alpha: FAILED (install.sh exit 1)"; has "failure trailer (update)" "FAILED — your installed version is unchanged and still works"
has "failed summary" "0 updated, 0 skipped, 1 failed"
eq "last-run lists the failed program" "failed: alpha" "$(sed -n 2p "$XDG_CACHE_HOME/ritz-get/last-run")"
eq "failed update reverted the clone" "$before" "$(sha alpha)"
exists "failed update keeps the link" "$HOME/.local/bin/alpha"
newcommit alpha ok; rg update --yes; has "update recovers" "alpha: updated"; rc "recovered update" 0

newcommit beta missing
rge RITZ_GET_OS_RELEASE=$T/os-arch update --yes; rc "update exit 3" 3
has "update needs line" "beta: FAILED (needs: gcc, pkgx)"; has "update deps line" "deps: sudo pacman -S --needed gcc p1 p2"
newcommit beta root; rg update --yes; rc "update exit 4" 4; has "update repeats needs root" "needs root: run ritz-get install beta"
newcommit beta ok; rg update --yes; rc "recover beta" 0

(cd "$T/work/alpha" && sed -i 's/spec: 1/spec: 2/' install.sh && git commit -qam spec2 && git push -q origin main)
before=$(sha alpha)
rg update --yes; rc "spec-2 update is skipped, not failed" 0
has "needs a newer ritz-get" "alpha: SKIPPED (needs a newer ritz-get)"; eq "spec-2 update reverted" "$before" "$(sha alpha)"
(cd "$T/work/alpha" && sed -i 's/spec: 2/spec: 1/' install.sh && git commit -qam spec1 && git push -q origin main)
rg update --yes >/dev/null

# ---- self-update -----------------------------------------------------------------------
newcommit ritz-get; newcommit alpha
before=$(sha ritz-get)
rg update --help; rc "update --help" 0; has "update --help prints usage" "usage: ritz-get"
eq "update --help does not self-update" "$before" "$(sha ritz-get)"
rg update --yes; rc "update with self-update" 0
has "ritz-get updated first" "ritz-get: updated"; has "restart message" "updated itself, restarting"
has "continued in the new script" "alpha: updated"; has "summary counts ritz-get" "2 updated, 0 skipped, 0 failed"
exists "ritz-get link" "$HOME/.local/bin/ritz-get"

# ---- modified: dirty, ahead, reset -----------------------------------------------------
echo x >>"$SRC/alpha/alpha"
newcommit alpha
rg list --porcelain
eq "dirty = modified (wins over behind)" "modified 1 0" "$(fld alpha 8) $(fld alpha 14) $(fld alpha 15)"
rg update --yes; rc "update skips a dirty clone" 0
has "modified skip line" "alpha: SKIPPED (local changes; ritz-get reset alpha to discard them)"
rg update alpha --yes; has "also for update NAME" "alpha: SKIPPED (local changes"
rgi n reset alpha; rc "reset declined" 0; has "reset asks what is lost" "1 changed file, 0 local commits"; has "aborted" "aborted"
exists "declined reset keeps the edit" "$SRC/alpha/alpha"; eq "edit still there" 1 "$(git -C "$SRC/alpha" status --porcelain | wc -l | tr -d ' ')"
rg hold alpha >/dev/null
rg reset alpha --yes; rc "reset --yes" 0; has "reset message" "alpha: reset to main"
eq "reset: clean again" 0 "$(git -C "$SRC/alpha" status --porcelain | wc -l | tr -d ' ')"
eq "reset: at the remote head" "$(git -C "$T/work/alpha" rev-parse HEAD)" "$(sha alpha)"
eq "reset clears the hold" 0 "$(git -C "$SRC/alpha" config --get-all ritz-get.hold | wc -l | tr -d ' ')"
git -C "$SRC/alpha" commit -q --allow-empty -m local
rg list --porcelain; eq "ahead = modified" "modified 0 1" "$(fld alpha 8) $(fld alpha 14) $(fld alpha 15)"
newcommit alpha; rg update --yes; has "ahead skips update" "alpha: SKIPPED (local changes"
rgi y reset alpha; rc "reset after confirmation" 0; has "prompt names local commits" "0 changed files, 1 local commit"
eq "reset dropped the local commit" "0" "$(git -C "$SRC/alpha" rev-list --count '@{u}..HEAD')"
touch "$SRC/alpha/marker"; newcommit alpha fail
rg reset alpha --yes; rc "reset with failing build" 1
exists "failed reset puts the old clone back" "$SRC/alpha/marker"; gone "no reset leftovers" "$SRC/.alpha.old"
rm "$SRC/alpha/marker"; newcommit alpha ok; rg update --yes >/dev/null
rg reset nope --yes; rc "reset unknown" 1
rg reset ritz-get --yes; rc "reset ritz-get" 0; has "reset ritz-get message" "ritz-get: reset to main"
exists "reset ritz-get: link re-created" "$HOME/.local/bin/ritz-get"; exists "reset ritz-get: clone back" "$SRC/ritz-get/ritz-get"

# ---- branches, switch ------------------------------------------------------------------
rg branches beta; rc "branches" 0
eq "branches output" "  dev
* main" "$(cat "$T/out")"
rg branches nope; rc "branches unknown" 1
rg switch beta dev; rc "switch beta dev" 0; has "switch message" "beta: now on dev"
eq "switched" dev "$(git -C "$SRC/beta" rev-parse --abbrev-ref HEAD)"
git -C "$SRC/beta" commit -q --allow-empty -m local-dev
git -C "$SRC/beta" checkout -q main
(cd "$T/work/beta" && git checkout -q dev && echo more >devfile && git commit -qam dev2 && git push -q origin dev && git checkout -q main)
rg switch beta dev; rc "switch with diverged branch" 1
has "ff-only failure aborts" "cannot fast-forward"
eq "still on the old branch" main "$(git -C "$SRC/beta" rev-parse --abbrev-ref HEAD)"
rg switch beta nonexistent; rc "switch to unknown branch" 1
git -C "$SRC/beta" branch -q -D dev
rg switch beta dev; rc "switch after dropping the local branch" 0
rg switch beta main >/dev/null

# ---- branch deleted on the remote ------------------------------------------------------
rg switch beta dev >/dev/null
git -C "$T/remote/t/beta.git" branch -q -D dev
rg list --porcelain; rc "branch-gone: list" 0
eq "branch-gone: status, latest, behind" "branch-gone - -" "$(fld beta 8) $(fld beta 12) $(fld beta 13)"
rg list; has "branch-gone: human hint" "branch dev deleted on the remote; pick another: ritz-get branches beta"
H=$(git -C "$SRC/beta" rev-parse HEAD)
rg update beta --yes; has "branch-gone: update skips" "beta: SKIPPED (branch dev was deleted on the remote; ritz-get branches beta, then ritz-get switch beta BRANCH)"
nol "branch-gone: not 'up to date'" "beta: up to date"
eq "branch-gone: clone untouched" "$H dev" "$(git -C "$SRC/beta" rev-parse HEAD) $(git -C "$SRC/beta" rev-parse --abbrev-ref HEAD)"
echo x >"$SRC/beta/gonefile"
rg list --porcelain; eq "branch-gone: dirty clone is modified" modified "$(fld beta 8)"
rm "$SRC/beta/gonefile"
rg switch beta main; rc "branch-gone: switch away" 0; has "branch-gone: switch message" "beta: now on main"
rg list --porcelain; eq "branch-gone: back to current" "current main" "$(fld beta 8) $(fld beta 10)"
git -C "$SRC/beta" branch -q -D dev
(cd "$T/work/beta" && git push -q origin dev)

# ---- remove, uninstall, unlisted -------------------------------------------------------
git clone -q "file://$T/remote/t/alpha.git" "$SRC/orphan"
rg list --porcelain
eq "unlisted state" "unlisted current Unlisted" "$(fld orphan 7) $(fld orphan 8) $(awk -F'\t' '$3 == "orphan" { print $2 }' "$T/out")"
rg update orphan --yes; has "unlisted: update refused" "orphan: SKIPPED (not in the manifest"
rg remove orphan; rc "remove an unlisted clone" 0; gone "unlisted clone deleted" "$SRC/orphan"
rg remove alpha; rc "remove" 0; has "removed line" "alpha: removed"
gone "remove: link gone" "$HOME/.local/bin/alpha"; gone "remove: clone gone" "$SRC/alpha"
rg uninstall beta; rc "uninstall alias" 0; gone "uninstall: clone gone" "$SRC/beta"
rg install beta >/dev/null; chmod -x "$SRC/beta/install.sh"
rg remove beta; rc "remove without an executable install.sh" 0; gone "no executable install.sh: clone gone" "$SRC/beta"
if [ -L "$HOME/.local/bin/beta" ]; then bad "no executable install.sh: no dangling link" "$HOME/.local/bin/beta is left"; else pass "no executable install.sh: no dangling link"; fi
rg remove nope; rc "remove unknown" 1; has "unknown, not 'not installed'" "unknown program: nope"
rg remove gamma; rc "remove known but not installed" 0; has "not installed" "gamma: not installed"
rg remove ritz-get; rc "remove ritz-get refused" 1; exists "ritz-get clone kept" "$SRC/ritz-get/.git"
rg remove; rc "remove without name" 2

# ---- lock ------------------------------------------------------------------------------
sh -c 'flock -n 9 && echo ready >"$0" && exec sleep 60' "$T/ready" 9>"$LOCK" &
HOLD=$!
i=0; while [ ! -e "$T/ready" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
rg install alpha; rc "busy: install" 5; has "busy message" "busy: another ritz-get is running"
rg update --yes; rc "busy: update" 5
rg hold ritz-get; rc "busy: hold" 5
rg list --offline; rc "list takes no lock" 0
rg branches ritz-get; rc "branches takes no lock" 0
env -u RITZ_GET_GUI sh "$RG" update --yes </dev/null >"$T/out" 2>"$T/err"; done_run
rc "cron (no tty, no GUI): busy update exits 0" 0
eq "cron: silent" "" "$(cat "$T/all")"
kill "$HOLD"; wait "$HOLD" 2>/dev/null; HOLD=
rg update --yes; rc "lock released with the process" 0

# ---- interrupt: INT/TERM stop a running build ------------------------------------------
newcommit zeta ok; rg install zeta >/dev/null; newcommit zeta slow; zold=$(sha zeta)
# intr SIGNAL CODE: update zeta (a 30 s build) in the background, signal ritz-get's pid, expect exit CODE soon
intr() {
	rm -f "$HOME/slow.pid" "$T/irc" "$T/ipid"
	set -m	# job control, so the background job does not start with SIGINT ignored
	( [ -z "$IQ" ] || unset RITZ_GET_GUI; sh -c 'echo $$ >"$1"; exec sh "$2" update zeta --yes' x "$T/ipid" "$RG" >"$T/out" 2>"$T/err" </dev/null; echo $? >"$T/irc" ) &
	set +m
	i=0; while [ ! -s "$HOME/slow.pid" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
	kill -"$1" "$(cat "$T/ipid")"
	i=0; while [ ! -s "$T/irc" ] && [ "$i" -lt 60 ]; do sleep 0.1; i=$((i + 1)); done
	if [ -s "$T/irc" ]; then pass "$IP$1: ritz-get exits within 6 s"; else bad "$IP$1: ritz-get exits within 6 s" "still running"; kill -KILL "$(cat "$T/ipid")"; fi
	sleep 0.3; cat "$T/out" "$T/err" >"$T/all"
	eq "$IP$1: exit code" "$2" "$(cat "$T/irc" 2>/dev/null)"
	has "$IP$1: FAILED (interrupted)" "zeta: FAILED (interrupted)"; has "$IP$1: trailer" "your installed version is unchanged"
	eq "$IP$1: old version still in place" "$zold" "$(sha zeta)"
	if kill -0 "$(cat "$HOME/slow.pid")" 2>/dev/null; then bad "$IP$1: install.sh is gone" "pid $(cat "$HOME/slow.pid") still runs"; else pass "$IP$1: install.sh is gone"; fi
	exists "$IP$1: link kept" "$HOME/.local/bin/zeta"
}
intr INT 130
intr TERM 143
IQ=1 IP="quiet " # the same without RITZ_GET_GUI: the awk consumer ends with the build
intr INT 130
intr TERM 143
IQ= IP=
rg remove zeta >/dev/null; rm -f "$HOME/slow.pid"

# ---- shortcuts -------------------------------------------------------------------------
APPS=$XDG_DATA_HOME/applications
kv() { sed -n "s/^$2=//p" "$1" | head -n 1; }	# first KEY= value of a .desktop file
rg shortcuts; eq "shortcuts: default folder" "$APPS" "$(cat "$T/out")"
rg install alpha shorty shorty2; rc "install shortcut fixtures" 0
gone "install does not create a shortcut" "$APPS/ritz-get-shorty.desktop"
rg shortcut alpha; rc "shortcut: repo ships no NAME.desktop" 1; has "no .desktop message" "ships no alpha.desktop"
rg shortcut gamma; rc "shortcut: not installed" 1; has "not installed message" "gamma is not installed"
rg shortcut nope; rc "shortcut: unknown" 1
rg shortcut; rc "shortcut without name" 2
rg shortcut shorty; rc "shortcut shorty" 0
SD=$APPS/ritz-get-shorty.desktop
eq "shortcut is a symlink to the generated file" "$SRC/.ritz-get/ritz-get-shorty.desktop" "$(readlink "$SD")"
exists "generated file lives in the repo folder" "$SRC/.ritz-get/ritz-get-shorty.desktop"
eq "Exec: first word is ~/.local/bin/NAME, args kept" "$HOME/.local/bin/shorty --flag %U" "$(kv "$SD" Exec)"
eq "Icon: the clone's icon.png (own Icon= ignored)" "$SRC/shorty/icon.png" "$(kv "$SD" Icon)"
eq "only one Icon=" 1 "$(grep -c '^Icon=' "$SD")"
eq "Name: manifest title" "Shorty Title" "$(kv "$SD" Name)"
eq "Categories gets X-Ritze03" "Utility;X-Ritze03;" "$(kv "$SD" Categories)"
eq "other keys and sections stay" "1 1" "$(grep -c '^Type=Application' "$SD") $(grep -c '^Exec=shorty --act' "$SD")"
rg shortcut shorty2; rc "shortcut shorty2" 0
SD2=$APPS/ritz-get-shorty2.desktop
eq "quoted Exec: first word replaced" "$HOME/.local/bin/shorty2 -x %f" "$(kv "$SD2" Exec)"
eq "no icon.png: no Icon=" 0 "$(grep -c '^Icon=' "$SD2")"
eq "missing Categories= is created" "X-Ritze03;" "$(kv "$SD2" Categories)"
eq "Name falls back to NAME" shorty2 "$(kv "$SD2" Name)"
rg shortcut site; rc "website shortcut" 0
SW=$APPS/ritz-get-site.desktop
eq "website: Exec xdg-open URL (quoted)" 'xdg-open "https://example.com/page#frag"' "$(kv "$SW" Exec)"
eq "website: Name = title" "Cool Site" "$(kv "$SW" Name)"
eq "website: Comment = description" "A site" "$(kv "$SW" Comment)"
eq "website: Categories" "Network;X-Ritze03;" "$(kv "$SW" Categories)"
eq "website: Type" Application "$(kv "$SW" Type)"
eq "website without icons/NAME.png: no Icon=" 0 "$(grep -c '^Icon=' "$SW")"
rg shortcut badurl; rc "website URL a shortcut can not carry" 1; has "bad URL message" "can not carry"
mkdir -p "$T/rgcopy/icons"; cp "$RG" "$T/rgcopy/ritz-get"; : >"$T/rgcopy/icons/site.png"
sh "$T/rgcopy/ritz-get" shortcut site >/dev/null 2>&1 </dev/null
eq "website icon: icons/NAME.png next to the script" "$(cd "$T/rgcopy" && pwd -P)/icons/site.png" "$(kv "$SW" Icon)"
rg shortcut site >/dev/null

rg list --porcelain --offline
eq "column 17: program with shortcut" on "$(fld shorty 17)"
eq "column 17: website with shortcut" on "$(fld site 17)"
eq "column 17: no NAME.desktop" - "$(fld alpha 17)"
eq "column 17: not installed" - "$(fld gamma 17)"
eq "column 17 on every row (17 fields)" 0 "$(awk -F'\t' '$1 == "E" && NF != 17' "$T/out" | wc -l | tr -d ' ')"
rg shortcut shorty --remove; rc "shortcut --remove" 0; has "removed message" "shorty: shortcut removed"
gone "shortcut link removed" "$SD"; gone "generated file removed" "$SRC/.ritz-get/ritz-get-shorty.desktop"
rg list --porcelain --offline alpha shorty
eq "column 17: capable, off" off "$(fld shorty 17)"
rg list shorty; has "human list NAME shows the shortcut state" "shortcut: off"
rg shortcut shorty --remove; rc "removing again is fine" 0; has "no shortcut message" "shorty: no shortcut"
git clone -q "file://$T/remote/t/alpha.git" "$SRC/orphan"; rg list --porcelain --offline orphan
eq "column 17: unlisted" - "$(fld orphan 17)"; rm -rf "$SRC/orphan"

rg shortcut shorty >/dev/null; rg remove shorty; rc "remove with a shortcut" 0
gone "remove: shortcut link gone" "$SD"; gone "remove: generated file gone" "$SRC/.ritz-get/ritz-get-shorty.desktop"
rg install shorty >/dev/null; rg shortcut shorty >/dev/null
printf junk >"$SRC/.ritz-get/ritz-get-shorty2.desktop"
rg install shorty2; rc "repair" 0; eq "repair regenerates the shortcut" "$HOME/.local/bin/shorty2 -x %f" "$(kv "$SD2" Exec)"
printf junk >"$SRC/.ritz-get/ritz-get-shorty2.desktop"; newcommit shorty2
rg update --yes; has "update shorty2" "shorty2: updated"
eq "update regenerates the shortcut" "$HOME/.local/bin/shorty2 -x %f" "$(kv "$SD2" Exec)"
printf junk >"$SRC/.ritz-get/ritz-get-shorty2.desktop"
rg reset shorty2 --yes; rc "reset" 0; eq "reset regenerates the shortcut" "$HOME/.local/bin/shorty2 -x %f" "$(kv "$SD2" Exec)"

mkdir -p "$XDG_CONFIG_HOME/ritz-get"; printf 'foo=bar\n' >"$XDG_CONFIG_HOME/ritz-get/config"
rg shortcuts "$T/menu"; rc "shortcuts PATH" 0
rg shortcuts; eq "shortcuts: new folder printed" "$T/menu" "$(cat "$T/out")"
eq "shortcuts: config keeps other keys" "foo=bar shortcuts=$T/menu" "$(grep -E '^(foo|shortcuts)=' "$XDG_CONFIG_HOME/ritz-get/config" | tr '\n' ' ' | sed 's/ $//')"
exists "shortcuts: program moved" "$T/menu/ritz-get-shorty2.desktop"; exists "shortcuts: website moved" "$T/menu/ritz-get-site.desktop"
gone "shortcuts: old folder emptied (program)" "$APPS/ritz-get-shorty2.desktop"; gone "shortcuts: old folder emptied (website)" "$APPS/ritz-get-site.desktop"
eq "shortcuts: link in the new folder" "$SRC/.ritz-get/ritz-get-shorty2.desktop" "$(readlink "$T/menu/ritz-get-shorty2.desktop")"
rg list --porcelain --offline site; eq "shortcuts: state follows the folder" on "$(fld site 17)"
rg shortcuts "$T/menu"; rc "shortcuts PATH (same)" 0; has "already message" "already in"
rg shortcuts "$APPS"; rc "shortcuts back to default" 0; exists "moved back" "$SD2"

# ---- open ------------------------------------------------------------------------------
rge PATH="$T/bin:$PATH" open site; rc "open website" 0
i=0; while [ ! -s "$T/xdg.log" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
eq "open: xdg-open gets the URL" "https://example.com/page#frag" "$(cat "$T/xdg.log" 2>/dev/null)"
rg open alpha; rc "open a program" 1; has "program, not a website" "alpha is a program, not a website"
rg open nope; rc "open unknown" 1
rg open; rc "open without name" 2

# ---- dir -------------------------------------------------------------------------------
rg dir; eq "dir prints the folder" "$SRC" "$(cat "$T/out")"
rg shortcut shorty >/dev/null
rg dir "$T/moved"; rc "dir without confirmation" 0; has "dir aborted" "aborted"
exists "aborted dir: nothing moved" "$SRC/alpha/.git"; gone "aborted dir: no target" "$T/moved"
eq "aborted dir: no config written" 0 "$(grep -c '^dir=' "$XDG_CONFIG_HOME/ritz-get/config")"
rgi n dir "$T/moved"; has "dir: answering n" "aborted"; exists "dir: n moved nothing" "$SRC/alpha/.git"
mkdir -p "$T/full"; touch "$T/full/x"
rg dir "$T/full" --yes; rc "dir into a non-empty folder" 1; has "non-empty message" "not empty"
exists "non-empty target: nothing moved" "$SRC/alpha/.git"
rg dir "$SRC/sub" --yes; rc "dir inside itself" 1; has "inside message" "inside the current folder"
if [ "$(stat -c %d /dev/shm 2>/dev/null)" != "$(stat -c %d "$T")" ] && [ -d /dev/shm ]; then
	rg dir "/dev/shm/ritz-get-test-$$/x" --yes; rc "dir across filesystems" 1
	has "cross-fs hint" "move it by hand, then run: ritz-get dir"; exists "cross-fs: nothing moved" "$SRC/alpha/.git"
	gone "cross-fs: nothing created" "/dev/shm/ritz-get-test-$$"
fi
rg dir "$T/moved" --yes; rc "dir move" 0
exists "dir: clones moved" "$T/moved/alpha/.git"; gone "dir: old folder gone" "$SRC"
rg dir; eq "dir prints the new folder" "$T/moved" "$(cat "$T/out")"
eq "dir: config written, other keys kept" "foo=bar dir=$T/moved" "$(grep -E '^(dir|foo)=' "$XDG_CONFIG_HOME/ritz-get/config" | tr '\n' ' ' | sed 's/ $//')"
MV=$(cd "$T/moved" && pwd -P)
eq "dir: ~/.local/bin link re-pointed" "$MV/alpha/alpha" "$(readlink "$HOME/.local/bin/alpha")"
eq "dir: ritz-get's own link re-pointed" "$MV/ritz-get/ritz-get" "$(readlink "$HOME/.local/bin/ritz-get")"
eq "dir: shortcut link re-pointed" "$T/moved/.ritz-get/ritz-get-shorty.desktop" "$(readlink "$SD")"
exists "dir: shortcut not dangling" "$SD"
eq "dir: shortcut regenerated (Icon)" "$T/moved/shorty/icon.png" "$(kv "$SD" Icon)"
eq "dir: website shortcut re-pointed" "$T/moved/.ritz-get/ritz-get-site.desktop" "$(readlink "$SW")"; exists "dir: website shortcut not dangling" "$SW"
eq "dir: website shortcut keeps Icon= (icons/ of the moved clone)" "$T/moved/ritz-get/icons/site.png" "$(kv "$SW" Icon)"
rg list --porcelain --offline; eq "dir: still installed" installed "$(fld alpha 7)"
mv "$T/moved" "$T/hand"
rg dir "$T/hand"; rc "dir after moving by hand" 0
rg dir; eq "hand-moved: config updated" "$T/hand" "$(cat "$T/out")"
eq "hand-moved: links repaired" "$(cd "$T/hand" && pwd -P)/alpha/alpha" "$(readlink "$HOME/.local/bin/alpha")"
eq "hand-moved: shortcuts repaired" "$T/hand/.ritz-get/ritz-get-shorty.desktop" "$(readlink "$SD")"
eq "hand-moved: website shortcut Icon=" "$T/hand/ritz-get/icons/site.png" "$(kv "$SW" Icon)"
mkdir -p "$T/empty"; echo fail >"$T/hand/alpha/mode"
rg dir "$T/empty" --yes; rc "dir with a failing repair" 1
has "needs repair line" "alpha: needs repair: ritz-get install alpha"
rg dir; eq "failed repair: the move stays" "$T/empty" "$(cat "$T/out")"
exists "dir into an existing empty folder" "$T/empty/shorty/.git"; gone "failed repair: old folder gone" "$T/hand"
eq "other programs still repaired" "$(cd "$T/empty" && pwd -P)/shorty/shorty" "$(readlink "$HOME/.local/bin/shorty")"
git -C "$T/empty/alpha" checkout -q mode
rg install alpha; rc "repair after a failed dir repair" 0
eq "repair re-points the link" "$(cd "$T/empty" && pwd -P)/alpha/alpha" "$(readlink "$HOME/.local/bin/alpha")"
rg dir "$SRC" --yes; rc "dir back to the default" 0; exists "default folder again" "$SRC/alpha/.git"
rg remove alpha shorty shorty2 >/dev/null; rg shortcut site --remove >/dev/null
gone "cleanup: shortcuts gone" "$SD2"; rm -f "$XDG_CONFIG_HOME/ritz-get/config"

# ---- D47: install offers the shortcut, remove takes it away ---------------------------
# The suite runs with RITZ_GET_GUI=1; here it is unset to act like a person at a shell.
S1=$APPS/ritz-get-shorty.desktop SW=$APPS/ritz-get-site.desktop
rgn() { env -u RITZ_GET_GUI timeout 60 sh "$RG" "$@" >"$T/out" 2>"$T/err" </dev/null; done_run; }
# rgt INPUT ARGS...: ritz-get on a pseudo-terminal (util-linux script), INPUT typed at it
rgt() { i=$1; shift; printf '%s' "$i" | env -u RITZ_GET_GUI timeout 60 script -qec "sh '$RG' $*" /dev/null >"$T/out" 2>"$T/err"; done_run; }
rgn install shorty --yes; rc "D47: install --yes" 0
has "D47: --yes says it created the shortcut" "shorty: shortcut created ($S1)"; exists "D47: install --yes creates the shortcut" "$S1"
lacks "D47: --yes does not ask" "start menu"
rg remove shorty; rc "D47: remove (program)" 0; gone "D47: remove takes the program's shortcut away" "$S1"
rgn install shorty; rc "D47: install, no tty, no --yes (does not hang)" 0
gone "D47: no tty and no --yes: no shortcut" "$S1"; lacks "D47: no tty: nobody is asked" "start menu"
rg remove shorty >/dev/null
rge RITZ_GET_GUI=1 install shorty --yes; rc "D47: install under RITZ_GET_GUI=1 --yes" 0
gone "D47: GUI=1: no shortcut" "$S1"; lacks "D47: GUI=1: no question" "start menu"; lacks "D47: GUI=1: nothing printed about a shortcut" "shortcut"
rg remove shorty >/dev/null
rgt 'n
' install shorty; rc "D47: tty, answer n" 0
has "D47: the question names the program" "Add Shorty Title to the start menu? [Y/n]"; gone "D47: answer n: no shortcut" "$S1"
rg remove shorty >/dev/null
rgt '
' install shorty; rc "D47: tty, plain Enter" 0
has "D47: Enter asked" "Add Shorty Title to the start menu? [Y/n]"; exists "D47: Enter means yes: shortcut" "$S1"
rgt 'n
' install shorty; rc "D47: repair with a shortcut" 0
has "D47: repair ran (the bar says so on a tty)" "shorty: repairing"; lacks "D47: repair with a shortcut does not ask again" "start menu"; exists "D47: repair keeps the shortcut" "$S1"
rg shortcut shorty --remove >/dev/null; newcommit shorty
rgn update --yes shorty; rc "D47: update" 0; has "D47: update did update" "shorty: updated"
lacks "D47: update does not ask" "start menu"; gone "D47: update adds no shortcut" "$S1"
rgn install shorty --yes; rc "D47: repair without a shortcut, --yes" 0; exists "D47: repair offers the shortcut" "$S1"
rgn remove shorty; rc "D47: remove (program), no GUI" 0; gone "D47: remove takes the shortcut by itself" "$S1"
rgn install alpha --yes; rc "D47: program without NAME.desktop" 0; lacks "D47: no desktop file: no question, no shortcut" "shortcut"
rg remove alpha >/dev/null
rg shortcut site >/dev/null; exists "D47: website shortcut set up" "$SW"
rg remove site; rc "D47: remove WEBSITE with a shortcut" 0; has "D47: website shortcut removed message" "site: shortcut removed"
gone "D47: website shortcut link gone" "$SW"; gone "D47: website generated file gone" "$SRC/.ritz-get/ritz-get-site.desktop"
rg remove site; rc "D47: remove WEBSITE without a shortcut" 0; has "D47: website without shortcut message" "site: no shortcut"
lacks "D47: a website is not 'not installed'" "not installed"

# ---- submodules ------------------------------------------------------------------------
# ritz-get does all the git work, submodules included. Remotes are local bare repos; the test gitconfig
# sets protocol.file.allow (ritz-get itself never does: real programs use https).
mkdir -p "$T/remote/sub" "$T/work/sublib"
(cd "$T/work/sublib" && git init -q -b main && echo v1 >data && git add -A && git commit -q -m v1 &&
	git clone -q --bare . "$T/remote/sub/lib.git" && git remote add origin "$T/remote/sub/lib.git" && git fetch -q origin)
mkrepo subby
cat >"$T/work/subby/install.sh" <<'EOT'
#!/bin/sh
# ritz-get-spec: 1
set -eu
cd "$(dirname "$0")"
case ${1:-} in
--install)
	[ "$(cat mode)" != fail ] || { echo boom >&2; exit 1; }
	mkdir -p build; cat lib/data >build/seen; echo "subby installed (lib=$(cat lib/data))" ;;
--remove) echo "subby removed" ;;
*) exit 2 ;;
esac
EOT
(cd "$T/work/subby" && git submodule add -q "file://$T/remote/sub/lib.git" lib && git add -A && git commit -q -m sub && git push -q origin main)
printf 'subby t/subby "Has a submodule"\n' >>"$T/programs"
# libcommit TEXT [nopush]: new commit in the submodule's remote; subpin [MODE]: point subby's main at it
libcommit() { (cd "$T/work/sublib" && echo "$1" >data && git add -A && git commit -q -m "$1" && { [ -n "${2:-}" ] || git push -q origin main; }); }
subpin() {
	(cd "$T/work/subby" && git checkout -q main && git -C lib fetch -q "$T/work/sublib" main && git -C lib checkout -q FETCH_HEAD &&
		{ [ -z "${1:-}" ] || echo "$1" >mode; } && git add -A && git commit -q -m pin && git push -q origin main)
}
seen() { eq "$1" "$2" "$(cat "$3/lib/data" 2>/dev/null) $(cat "$3/build/seen" 2>/dev/null)"; }	# submodule checkout + what the build saw
SB=$SRC/subby

rg install subby; rc "submodules: install" 0; has "install built it" "subby installed (lib=v1)"
seen "install initialises the submodule" "v1 v1" "$SB"
if [ -f "$SB/lib/.git" ]; then pass "submodule .git is a gitfile"; else bad "submodule .git is a gitfile" "not a file"; fi
eq "initialised submodule: clone is not modified" "" "$(git -C "$SB" status --porcelain)"
rg list --porcelain; eq "initialised submodule: status current" current "$(fld subby 8)"
git -C "$SB" submodule deinit -q -f lib
eq "un-initialised submodule: nothing in git status" "" "$(git -C "$SB" status --porcelain)"
rg list --porcelain; eq "un-initialised submodule: not modified" "current 0 0" "$(fld subby 8) $(fld subby 14) $(fld subby 15)"
rg install subby; rc "repair re-initialises the submodule" 0; seen "repair: submodule back" "v1 v1" "$SB"

libcommit v2; subpin; rg update --yes; rc "update bumps the pointer" 0; has "update message" "subby: updated"
seen "update moves the submodule" "v2 v2" "$SB"
eq "update: clone clean" "" "$(git -C "$SB" status --porcelain)"

o=$(sha subby); libcommit v3; subpin fail
rg update --yes; rc "failing build with a new pin" 1; has "failed build reported" "subby: FAILED (install.sh exit 1)"
eq "failed build: commit reverted" "$o" "$(sha subby)"
seen "failed build: submodule checkout reverted" "v2 v2" "$SB"
eq "failed build: clone clean again" "" "$(git -C "$SB" status --porcelain)"
(cd "$T/work/subby" && echo ok >mode && git add -A && git commit -q -m okmode && git push -q origin main)
rg update --yes; rc "update recovers" 0; seen "recovered: submodule at v3" "v3 v3" "$SB"

# a branch with a different pin; one whose build fails
(cd "$T/work/subby" && git checkout -q -b pin && git -C lib checkout -q "$(git -C "$T/work/sublib" rev-parse HEAD~2)" && git add -A &&
	git commit -q -m oldpin && git push -q origin pin && git checkout -q -b badpin && echo fail >mode && git add -A &&
	git commit -q -m bad && git push -q origin badpin && git checkout -q main && git submodule update -q)
rg switch subby pin; rc "switch to a branch with another pin" 0; has "switch message" "subby: now on pin"
seen "switch moves the submodule" "v1 v1" "$SB"
eq "switch: clone clean" "" "$(git -C "$SB" status --porcelain)"
rg switch subby badpin; rc "switch to a failing branch" 1
eq "failed switch: back on pin" pin "$(git -C "$SB" rev-parse --abbrev-ref HEAD)"; seen "failed switch: submodule reverted" "v1 v1" "$SB"
eq "failed switch: clone clean" "" "$(git -C "$SB" status --porcelain)"
rg switch subby main; rc "switch back" 0; seen "switch back: submodule at v3" "v3 v3" "$SB"

# local edits inside a submodule count as modified; reset discards them
echo mine >"$SB/lib/data"
rg list --porcelain; eq "edited submodule = modified" "modified" "$(fld subby 8)"
rg update --yes; has "edited submodule: update skips" "subby: SKIPPED (local changes"
rg reset subby --yes; rc "reset with an edited submodule" 0; has "reset message" "subby: reset to main"
seen "reset: pristine submodule" "v3 v3" "$SB"
eq "reset: clone clean" "" "$(git -C "$SB" status --porcelain)"
rg list --porcelain; eq "reset: not modified" current "$(fld subby 8)"

# a pin that does not exist upstream: update fails and reverts; a fresh install fails and cleans up
o=$(sha subby); libcommit v4 nopush; subpin
rg update --yes; rc "update with an unfetchable pin" 1; has "submodule failure reported" "subby: FAILED (submodules: "
eq "submodule failure: commit reverted" "$o" "$(sha subby)"; seen "submodule failure: submodule untouched" "v3 v3" "$SB"
eq "submodule failure: clone clean" "" "$(git -C "$SB" status --porcelain)"
rg remove subby >/dev/null; rg install subby; rc "install with an unfetchable pin" 1
has "install: submodule failure reported" "subby: FAILED (submodules: "; gone "failed install: clone removed" "$SB"
(cd "$T/work/sublib" && git push -q origin main)
rg install subby; rc "install once the pin exists" 0; seen "install at the new pin" "v4 v4" "$SB"

# moving the folder keeps the submodule working (its .git is a relative gitfile)
rg dir "$T/submoved" --yes; rc "dir move with a submodule" 0
SM=$(cd "$T/submoved" && pwd -P)/subby
eq "moved: submodule still a checkout" "v4 v4" "$(cat "$SM/lib/data") $(cat "$SM/build/seen")"
eq "moved: git works in the submodule" "$(git -C "$SM" rev-parse HEAD:lib)" "$(git -C "$SM/lib" rev-parse HEAD)"
eq "moved: clone clean" "" "$(git -C "$SM" status --porcelain)"
libcommit v5; subpin; rg update --yes; rc "update after the move" 0; seen "moved: update bumps the submodule" "v5 v5" "$SM"
rg dir "$SRC" --yes; rc "dir back (submodule program)" 0; seen "back: submodule intact" "v5 v5" "$SB"
rg remove subby >/dev/null; gone "remove: clone with submodule deleted" "$SB"

# ---- the real programs file ------------------------------------------------------------
rge RITZ_GET_MANIFEST="$ROOT/programs" list --offline --porcelain; rc "real programs file parses" 0
names() { awk -F'\t' '$1 == "E" { print $3 }' "$T/out" | tr '\n' ' ' | sed 's/ $//'; }
eq "real programs: sections in order" "Software Helpers Websites Other" "$(awk -F'\t' '$1 == "E" { print $2 }' "$T/out" | uniq | tr '\n' ' ' | sed 's/ $//')"
eq "real programs: entries" "yt-dlp-gui ritz ForzaTelemetryV3Launcher ForzaTelemetryV3 simple-screensharing geofinder SteamAlt gamescope-ritz ritz-get ritz-get-gui ccorral ts6tray cs2-alias-cycling cs2-chat-keybind cs2-multimap simple-screensharing-web walters-knaggertreff ts6-themes" "$(names)"
eq "real programs: ts6tray setup lines" 2 "$(awk -F'\t' '$1 == "S" && $2 == "ts6tray"' "$T/out" | wc -l | tr -d ' ')"
eq "real programs: descriptions 1-80 chars without quote, titles <= 40" 0 "$(awk -F'\t' '$1 == "E" && (length($16) < 1 || length($16) > 80 || $16 ~ /"/ || length($4) > 40 || length($4) < 1)' "$T/out" | wc -l | tr -d ' ')"
eq "real programs: websites have URLs" 6 "$(awk -F'\t' '$1 == "E" && $5 == "website" && $6 ~ /^https:\/\//' "$T/out" | wc -l | tr -d ' ')"
eq "Software entries" "yt-dlp-gui ritz ForzaTelemetryV3Launcher ForzaTelemetryV3 simple-screensharing geofinder SteamAlt gamescope-ritz" "$(awk -F'\t' '$1 == "E" && $2 == "Software" { print $3 }' "$T/out" | tr '\n' ' ' | sed 's/ $//')"
eq "SteamAlt title" "Steam Userdata Copier" "$(fld SteamAlt 4)"
eq "Software entries: valid description and title" 0 "$(awk -F'\t' '$1 == "E" && (length($16) < 1 || length($16) > 80 || $16 ~ /"/ || length($4) > 40)' "$T/out" | wc -l | tr -d ' ')"

# ---- the one-time installer ------------------------------------------------------------
# inst HOME [ENV=val...]: no controlling terminal (setsid), stdin /dev/null, XDG_* unset, manifest from the clone
inst() {
	h=$1; shift; mkdir -p "$h"
	setsid -w env -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u RITZ_GET_MANIFEST -u RITZ_GET_DIR HOME="$h" SHELL=/bin/bash "$@" \
		sh "$ROOT/install-ritz-get.sh" >"$T/out" 2>"$T/err" </dev/null; done_run
}
inst "$T/ih1" RITZ_GET_DIR="$T/ih1/clones"; rc "installer (no tty, RITZ_GET_DIR)" 0
exists "installer: clone in RITZ_GET_DIR" "$T/ih1/clones/ritz-get/.git"
eq "installer: config written for a non-default folder" "dir=$T/ih1/clones" "$(cat "$T/ih1/.config/ritz-get/config")"
eq "installer: ran install.sh" "$T/ih1/clones/ritz-get/ritz-get" "$(readlink "$T/ih1/.local/bin/ritz-get")"
has "installer: PATH hint" 'export PATH="$HOME/.local/bin:$PATH"'
eq "installer: PATH hint printed once" 1 "$(grep -c 'not in your PATH' "$T/all")"
gone "installer: no tty, no ~/.profile edit" "$T/ih1/.profile"
gone "installer: no tty, no GUI" "$T/ih1/clones/ritz-get-gui"
eq "installer: the installed ritz-get uses the folder" "$T/ih1/clones" "$(env -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u RITZ_GET_MANIFEST HOME="$T/ih1" sh "$T/ih1/.local/bin/ritz-get" dir)"
inst "$T/ih1" RITZ_GET_DIR="$T/ih1/clones"; rc "installer, second run" 0; has "already installed" "already installed"; has "points to update" "ritz-get update"
inst "$T/ih1"; rc "installer, second run, folder from the config" 0
eq "second run: 'already installed' comes first" "ritz-get is already installed in $T/ih1/clones/ritz-get - use: ritz-get update" "$(head -n 1 "$T/out")"
lacks "second run: no folder question" "Folder for the clones"
mkdir -p "$T/ih2"
setsid -w env -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u RITZ_GET_MANIFEST -u RITZ_GET_DIR HOME="$T/ih2" \
	sh -c 'cat "$0" | sh' "$ROOT/install-ritz-get.sh" >"$T/out" 2>"$T/err" </dev/null; done_run
rc "installer piped into sh (stdin is the script)" 0
exists "piped: default folder" "$T/ih2/.local/share/ritz-get/src/ritz-get/.git"; gone "piped: no config for the default folder" "$T/ih2/.config/ritz-get/config"
# a terminal: answers come from RITZ_GET_TTY (the hook for /dev/tty)
printf '%s\ny\ny\n' "$T/ih3/f" >"$T/ans3"
inst "$T/ih3" RITZ_GET_TTY="$T/ans3"; rc "installer with answers (folder, PATH yes, GUI yes)" 0
eq "answers: folder" "dir=$T/ih3/f" "$(cat "$T/ih3/.config/ritz-get/config")"
has "answers: PATH edit" "Added to ~/.profile."; has "answers: profile has the line" ".local/bin"
has "answers: the prompt names the file" "Add it to ~/.profile for you now?"
eq "answers: ~/.profile" 'export PATH="$HOME/.local/bin:$PATH"' "$(grep '^export PATH' "$T/ih3/.profile")"
exists "answers: GUI installed" "$T/ih3/f/ritz-get-gui/.git"
exists "answers: GUI shortcut" "$T/ih3/.local/share/applications/ritz-get-ritz-get-gui.desktop"
has "answers: app menu hint" "Open ritz-get-gui from your app menu"
newcommit ritz-get-gui missing
printf '\nn\n\n' >"$T/ans4"
inst "$T/ih4" RITZ_GET_TTY="$T/ans4" RITZ_GET_OS_RELEASE="$T/os-arch"; rc "installer: GUI needs tools is not a failure" 0
has "GUI deps header" "ritz-get is installed; the GUI needs these first:"
has "GUI deps line" "deps: sudo pacman -S --needed gcc p1 p2"
exists "defaults: blank folder answer" "$T/ih4/.local/share/ritz-get/src/ritz-get/.git"; gone "no PATH edit after n" "$T/ih4/.profile"
lacks "no app menu hint" "Open ritz-get-gui from your app menu"
mkdir -p "$T/nogit"; ln -sf "$(command -v id)" "$T/nogit/id"
setsid -w env PATH="$T/nogit" HOME="$T/ih5" RITZ_GET_OS_RELEASE="$T/os-other" "$(command -v sh)" "$ROOT/install-ritz-get.sh" >"$T/out" 2>"$T/err" </dev/null; done_run
rc "installer without git" 3; has "missing git line" "missing: git (try: pacman:git dnf:git apt:git)"
lacks "no git hint: unknown distro" "sudo"
for d in arch:"sudo pacman -S git" fedora:"sudo dnf install git" ubuntu:"sudo apt install git"; do
	setsid -w env PATH="$T/nogit" HOME="$T/ih5" RITZ_GET_OS_RELEASE="$T/os-${d%%:*}" "$(command -v sh)" "$ROOT/install-ritz-get.sh" >"$T/out" 2>"$T/err" </dev/null; done_run
	rc "installer without git on ${d%%:*}" 3; has "git hint for ${d%%:*}" "${d#*:}"
done

# PATH line: the login file the shell reads (zsh: .zprofile; bash: .bash_profile, .bash_login, .profile)
printf '\ny\nn\n' >"$T/ansp"
inst "$T/ihz" RITZ_GET_TTY="$T/ansp" SHELL=/usr/bin/zsh; rc "installer, zsh" 0
has "zsh: prompt names ~/.zprofile" "Add it to ~/.zprofile for you now?"; has "zsh: confirmation names it" "Added to ~/.zprofile."
exists "zsh: ~/.zprofile written" "$T/ihz/.zprofile"; gone "zsh: ~/.profile untouched" "$T/ihz/.profile"
mkdir -p "$T/ihb"; : >"$T/ihb/.bash_profile"; : >"$T/ihb/.bash_login"
inst "$T/ihb" RITZ_GET_TTY="$T/ansp"; rc "installer, bash with ~/.bash_profile" 0
has "bash_profile: confirmation names it" "Added to ~/.bash_profile."; eq "bash_profile: line added" 1 "$(grep -c '^export PATH' "$T/ihb/.bash_profile")"
gone "bash_profile: ~/.profile untouched" "$T/ihb/.profile"; eq "bash_profile: ~/.bash_login untouched" 0 "$(wc -c <"$T/ihb/.bash_login" | tr -d ' ')"
mkdir -p "$T/ihl"; : >"$T/ihl/.bash_login"
inst "$T/ihl" RITZ_GET_TTY="$T/ansp"; rc "installer, bash with ~/.bash_login" 0
has "bash_login: confirmation names it" "Added to ~/.bash_login."; gone "bash_login: ~/.profile untouched" "$T/ihl/.profile"

# a failing install.sh: the new clone is deleted, a rerun does not claim success
mkdir -p "$T/remote2/Ritze03" "$T/work/bad"
printf '#!/bin/sh\necho nope >&2\nexit 1\n' >"$T/work/bad/install.sh"; chmod +x "$T/work/bad/install.sh"
(cd "$T/work/bad" && git init -q -b main && git add -A && git commit -q -m v0 && git clone -q --bare . "$T/remote2/Ritze03/ritz-get.git")
inst "$T/ihf" RITZ_GET_DIR="$T/ihf/c" RITZ_GET_GIT_BASE="file://$T/remote2"; rc "installer, failing install.sh" 1
has "failing: says so" "ritz-get's install.sh failed"; gone "failing: the new clone is deleted" "$T/ihf/c/ritz-get"; gone "failing: no link" "$T/ihf/.local/bin/ritz-get"
inst "$T/ihf" RITZ_GET_DIR="$T/ihf/c"; rc "rerun after the failure installs for real" 0
lacks "rerun: no false 'already installed'" "already installed"; exists "rerun: link exists" "$T/ihf/.local/bin/ritz-get"
mkdir -p "$T/ihe/c/ritz-get"
inst "$T/ihe" RITZ_GET_DIR="$T/ihe/c" RITZ_GET_GIT_BASE="file://$T/remote2"; rc "failing install.sh into an existing empty folder" 1
exists "pre-existing folder is kept" "$T/ihe/c/ritz-get"; eq "pre-existing folder is emptied again" 0 "$(ls -A "$T/ihe/c/ritz-get" | wc -l | tr -d ' ')"
# a clone without its link is repaired by re-running install.sh, not reported as installed
rm -f "$T/ihf/.local/bin/ritz-get"
inst "$T/ihf" RITZ_GET_DIR="$T/ihf/c"; rc "installer, clone without link" 0
has "no link: repairing" "repairing"; lacks "no link: not 'already installed'" "already installed"
eq "no link: link restored" "$T/ihf/c/ritz-get/ritz-get" "$(readlink "$T/ihf/.local/bin/ritz-get")"
ln -sfn /nowhere/ritz-get "$T/ihf/.local/bin/ritz-get"
inst "$T/ihf" RITZ_GET_DIR="$T/ihf/c"; rc "installer, link pointing elsewhere" 0
eq "elsewhere: link restored" "$T/ihf/c/ritz-get/ritz-get" "$(readlink "$T/ihf/.local/bin/ritz-get")"

# ---- progress: #start/#progress for the GUI, a bar on a terminal, nothing extra anywhere else -------
# before A B: A is printed on an earlier line than B (stdout)
before() { eq "$1" 1 "$(awk -v a="$2" -v b="$3" 'index($0, a) == 1 && !x { x = NR } index($0, b) == 1 { y = NR } END { print (x && y && x < y) ? 1 : 0 }' "$T/out")"; }
# rgb COLS LOCALE INPUT ARGS...: ritz-get on a pty with a terminal type, so the bar is on
rgb() { w=$1 l=$2 i=$3; shift 3; printf '%s' "$i" | env -u RITZ_GET_GUI TERM=xterm COLUMNS="$w" LC_ALL="$l" timeout 60 script -qec "sh '$RG' $*" /dev/null >"$T/out" 2>"$T/err"; done_run; }
# screen: what a terminal would show of $T/out (a line ends at the last CR; ESC[K erases)
screen() { awk '{ sub(/\r$/, ""); n = split($0, a, "\r"); s = a[n]; gsub(/\033\[K/, "", s); print s }' "$T/out"; }
ESC=$(printf '\033')
rg remove alpha beta >/dev/null
rg install alpha; rc "progress: GUI install" 0
eq "progress: GUI install: the marker lines are exactly #start and #progress 1/1" "#start alpha
#progress alpha 1/1" "$(grep '^#' "$T/out")"
eq "progress: GUI install: #start is the first line" "#start alpha" "$(head -n 1 "$T/out")"
before "progress: GUI install: #start comes before the result line" "#start alpha" "alpha: installed"
before "progress: GUI install: #progress comes after the result line" "alpha: installed" "#progress alpha 1/1"
rg remove alpha; lacks "progress: remove has no markers" "#start"
rg install alpha beta >/dev/null; newcommit alpha; newcommit beta
rg update --yes alpha beta; rc "progress: GUI update of two" 0
eq "progress: GUI update: N/M runs 1/2, 2/2 over the apply list, in order" "#start alpha
#progress alpha 1/2
#start beta
#progress beta 2/2" "$(grep '^#' "$T/out")"
before "progress: GUI update: alpha's result sits between its markers" "#start alpha" "alpha: updated"
before "progress: GUI update: alpha is done before beta starts" "#progress alpha 1/2" "#start beta"
before "progress: GUI update: beta's result comes before its #progress" "beta: updated" "#progress beta 2/2"
before "progress: GUI update: markers come before the summary" "#progress beta 2/2" "2 updated, 0 skipped, 0 failed"
newcommit alpha
rg update --yes alpha beta; rc "progress: GUI update, one up to date" 0
eq "progress: GUI update: M counts only what is applied" "#start alpha
#progress alpha 1/1" "$(grep '^#' "$T/out")"
has "progress: GUI update: the up-to-date program is still reported" "beta: up to date"
rg update --yes alpha beta; eq "progress: GUI update, nothing to do: no markers" "" "$(grep '^#' "$T/out")"
rg switch beta dev; rc "progress: GUI switch" 0
eq "progress: GUI switch: 1/1" "#start beta
#progress beta 1/1" "$(grep '^#' "$T/out")"
rg reset beta --yes; rc "progress: GUI reset" 0
eq "progress: GUI reset: 1/1" "#start beta
#progress beta 1/1" "$(grep '^#' "$T/out")"
rg install alpha gamma; eq "progress: GUI install of two (repair + failing build): 1/2, 2/2" "#start alpha
#progress alpha 1/2
#start gamma
#progress gamma 2/2" "$(grep '^#' "$T/out")"
# not a terminal, not the GUI: nothing but today's lines (cron, pipes, ritz-get update --yes >log)
rgn remove alpha beta gamma >/dev/null
rgn install alpha beta; rc "progress: no tty, no GUI: install" 0
if grep -q '^#' "$T/out" || grep -q "$ESC" "$T/all" || [ -n "$(tr -d -c '\r' <"$T/all")" ]; then bad "progress: no tty, no GUI: install prints no marker, bar or CR" "$(head -c 300 "$T/all" | od -c | head -n 5)"; else pass "progress: no tty, no GUI: install prints no marker, bar or CR"; fi
eq "progress: no tty, no GUI: install is quiet, just the program lines (D48)" "alpha: cloning t/alpha
alpha: building
alpha: installed main $(git -C "$SRC/alpha" rev-parse --short HEAD)
Additional steps required:
  Open the app and press go
  Docs: https://example.com/x#y
beta: cloning t/beta
beta: building
beta: installed main $(git -C "$SRC/beta" rev-parse --short HEAD)" "$(cat "$T/out")"
newcommit alpha; newcommit beta
o=$(git -C "$SRC/alpha" rev-parse --short HEAD); o2=$(git -C "$SRC/beta" rev-parse --short HEAD)
rgn update --yes alpha beta; rc "progress: no tty, no GUI: update" 0
if grep -q '^#' "$T/out" || grep -q "$ESC" "$T/all" || [ -n "$(tr -d -c '\r' <"$T/all")" ]; then bad "progress: no tty, no GUI: update prints no marker, bar or CR" "$(head -c 300 "$T/all" | od -c | head -n 5)"; else pass "progress: no tty, no GUI: update prints no marker, bar or CR"; fi
eq "progress: no tty, no GUI: update output is just the program lines and the summary" "alpha: updated $o -> $(git -C "$SRC/alpha" rev-parse --short HEAD)
beta: updated $o2 -> $(git -C "$SRC/beta" rev-parse --short HEAD)
2 updated, 0 skipped, 0 failed" "$(cat "$T/out")"
# on a terminal: a bar while it works, gone again before the lines that stay
newcommit alpha; newcommit beta
rgb 60 C '' update --yes alpha beta; rc "progress: pty update" 0
has "progress: pty: the bar shows 1/2 with the name and step" "] 1/2  alpha: building"
has "progress: pty: the bar shows 2/2" "] 2/2  beta: building"
has "progress: pty: the bar is plain ASCII in the C locale" "[--"
lacks "progress: pty: no GUI markers" "#start"
eq "progress: pty: the last line on screen is the summary" "2 updated, 0 skipped, 0 failed" "$(screen | grep -v '^$' | tail -n 1)"
eq "progress: pty: no bar is left on screen" 0 "$(screen | grep -c '^\[')"
eq "progress: pty: the scrollback is today's lines" "alpha: updated $(git -C "$SRC/alpha" rev-parse --short HEAD~1) -> $(git -C "$SRC/alpha" rev-parse --short HEAD)
beta: updated $(git -C "$SRC/beta" rev-parse --short HEAD~1) -> $(git -C "$SRC/beta" rev-parse --short HEAD)
2 updated, 0 skipped, 0 failed" "$(screen | grep -v '^$')"
newcommit alpha; newcommit beta
rgb 60 C.UTF-8 "" update --yes alpha beta; rc "progress: pty update in UTF-8" 0
has "progress: pty: UTF-8 locale draws blocks" "█"
rgb 60 C.UTF-8 "" reset alpha --yes; rc "progress: pty reset in UTF-8" 0
has "progress: pty: UTF-8 bar has the empty part too" "░"
has "progress: pty: reset shows the cloning step" "1/1  alpha: cloning"
eq "progress: pty: reset leaves no bar" 0 "$(screen | grep -c '^\[')"
newcommit alpha
narrow() { eq "$1" "0 1" "$(tr "\r" "\n" <"$T/out" | grep -a "^${ESC}\[K\[" | awk 'length($0) - 3 > 21 { n++ } END { print n + 0, (NR > 0) }')"; }
rgb 22 C "" update --yes alpha; rc "progress: pty on a narrow terminal" 0
narrow "progress: pty: the update bar never reaches the last column"
rgb 22 C '' install alpha; rc "progress: pty repair on a narrow terminal" 0
narrow "progress: pty: the repair bar never reaches the last column"
rgb 60 C '' install nonesuch; rc "progress: pty, unknown program" 1
eq "progress: pty: no bar for a run that applies nothing" 0 "$(grep -a -c '\] 1/1' "$T/out")"
rgn remove alpha beta >/dev/null
# the bar fills by steps and never goes back; on a terminal it replaces the transient status lines
# frames: the bar frames in $T/out, one per line; fills: the number of full cells of each
frames() { tr "\r" "\n" <"$T/out" | sed 's/\x1b\[K//' | grep -a '^\[[#-]*\] '; }
fills() { frames | awk '{ print gsub(/#/, "#", $1) }'; }
nol() { eq "$1" 0 "$(screen | grep -c "$2")"; }
mono() { eq "$1" 1 "$(fills | awk 'NR > 1 && $1 < p { b = 1 } { p = $1 } END { print (NR > 1 && !b) ? 1 : 0 }')"; }
rgb 60 C '' install alpha beta; rc "bar: pty install of two" 0
mono "bar: pty install of two: the fill never decreases"
eq "bar: pty install of two: starts empty, ends past half" "0 1" "$(fills | awk 'NR == 1 { a = $1 } { m = $1 } END { print a, (m > 7) }')"
eq "bar: pty install of two: beta's first frame is at the middle or later" 1 "$(frames | grep -a ' 2/2 ' | head -n 1 | awk '{ print (gsub(/#/, "#", $1) >= 7) }')"
nol "bar: pty install: no 'cloning' status line (the bar's label says it)" "alpha: cloning t/alpha"
nol "bar: pty install: no 'building' status line" "alpha: building"
eq "bar: pty install of two: the lines that stay" "alpha: installed main $(git -C "$SRC/alpha" rev-parse --short HEAD)
Additional steps required:
  Open the app and press go
  Docs: https://example.com/x#y
beta: installed main $(git -C "$SRC/beta" rev-parse --short HEAD)" "$(screen | grep -v '^$')"
eq "bar: pty install of two: no bar is left" 0 "$(screen | grep -c '^\[')"
rgn remove alpha beta >/dev/null
rgn install alpha; has "bar: no tty: the cloning status line is still printed" "alpha: cloning t/alpha"
has "bar: no tty: ... and the building one" "alpha: building"
rgn install alpha; has "bar: no tty: the repairing status line is still printed" "alpha: installed, repairing (re-running install.sh)"
rgb 60 C '' install alpha; rc "bar: pty repair" 0
mono "bar: pty repair: the fill never decreases"
nol "bar: pty repair: no repairing status line" "installed, repairing"
rgn install beta >/dev/null; newcommit alpha; newcommit beta
rgb 60 C '' update --yes alpha beta; rc "bar: pty update of two" 0
mono "bar: pty update of two: the fill never decreases"
eq "bar: pty update of two: beta's first frame is at the middle or later" 1 "$(frames | grep -a ' 2/2 ' | head -n 1 | awk '{ print (gsub(/#/, "#", $1) >= 7) }')"
rgb 60 C '' switch beta dev; rc "bar: pty switch" 0
mono "bar: pty switch: the fill never decreases"
nol "bar: pty switch: no 'building' status line" "beta: building"
has "bar: pty switch: the result stays" "beta: now on dev"
rgb 60 C '' reset beta --yes; rc "bar: pty reset" 0
mono "bar: pty reset: the fill never decreases"
nol "bar: pty reset: no 'cloning' status line" "beta: cloning"
rgn remove alpha beta >/dev/null

# ---- quiet builds (D48): install.sh's output goes to a log; only what a friend must act on stays on screen ----
mkrepo noisy 1 noisy; mkrepo loud 1 loud
printf 'noisy t/noisy "Noisy"\nloud t/loud "Loud"\ngamma t/gamma "Needs tools"\ntheta t/theta "Needs other tools"\nalpha t/alpha "Alpha program"\n' >"$T/programs2"
RITZ_GET_MANIFEST=$T/programs2; export RITZ_GET_MANIFEST
LG=$XDG_CACHE_HOME/ritz-get/logs
rgn install noisy; rc "quiet: install" 0
eq "quiet: stdout is the program lines plus what to act on (note:, restart:, setup:)" "noisy: cloning t/noisy
noisy: building
note: start it with: noisy --daemon
restart: noisy to use the new version
setup: do the thing
noisy: installed main $(git -C "$SRC/noisy" rev-parse --short HEAD)" "$(cat "$T/out")"
lacks "quiet: the chatter is not on screen" "compiling noisy"
if grep -q "$ESC" "$T/all" || [ -n "$(tr -d -c '\r' <"$T/all")" ]; then bad "quiet: no CR or ESC without a tty" "$(od -c "$T/all" | head -n 3)"; else pass "quiet: no CR or ESC without a tty"; fi
exists "quiet: the build log exists" "$LG/noisy.log"
eq "quiet: the log starts with a header (date, command, commit)" "# $(date +%F) " "$(head -n 1 "$LG/noisy.log" | cut -c 1-13)"
match "quiet: the header names the command and the commit" "noisy install.sh --install --yes  $(git -C "$SRC/noisy" rev-parse --short HEAD)\$" "$(head -n 1 "$LG/noisy.log")"
eq "quiet: the log has the chatter, stdout and stderr in order" "compiling noisy...
note: start it with: noisy --daemon
restart: noisy to use the new version
setup: do the thing
done" "$(sed -n 2,6p "$LG/noisy.log")"
rgn install noisy; rc "quiet: repair" 0
eq "quiet: the log is overwritten, not appended" 1 "$(grep -c '^compiling' "$LG/noisy.log")"
rgn install loud; rc "quiet: failing build" 1
has "quiet: FAILED line names the log" "loud: FAILED (install.sh exit 1) — build log: $LG/loud.log"
has "quiet: the end of the log is shown, indented" "  step 20"
has "quiet: ... including stderr" "  oops"
has "quiet: ... 15 lines of it" "  step 7"
lacks "quiet: ... and no more" "step 6"
eq "quiet: nothing is streamed (the tail is the only copy)" 1 "$(grep -c 'step 20' "$T/all")"
has "quiet: the first-install trailer is still there" "FAILED — nothing was installed"
lacks "quiet: ... and does not claim an unchanged version" "installed version is unchanged"
eq "quiet: the failed first install keeps its log (cleanup does not overwrite it)" 1 "$(grep -c '^oops' "$LG/loud.log")"
RITZ_GET_OS_RELEASE=$T/os-arch; export RITZ_GET_OS_RELEASE
rgn install gamma theta; rc "quiet: missing tools" 3
has "quiet: missing: lines are shown" "missing: gcc (try: pacman:gcc dnf:gcc apt:build-essential)"
has "quiet: FAILED line as before (no log suffix for exit 3)" "gamma: FAILED (needs: gcc, pkgx)"
lacks "quiet: exit 3 does not dump a log tail" "build log"
eq "quiet: one deps: line, merged over both programs" "deps: sudo pacman -S --needed gcc nap p1 p2" "$(grep '^deps:' "$T/out")"
unset RITZ_GET_OS_RELEASE
rgn install noisy --verbose; rc "verbose: install" 0
has "verbose: the chatter is streamed" "compiling noisy..."
has "verbose: install.sh's own lines are streamed" "noisy installed spec=1"
eq "verbose: the log is written too" 1 "$(grep -c '^compiling' "$LG/noisy.log")"
rgn install noisy -v; rc "verbose: -v" 0; has "verbose: -v streams the chatter" "compiling noisy..."
rgn install loud --verbose; rc "verbose: failing build" 1
has "verbose: FAILED line names the log" "loud: FAILED (install.sh exit 1) — build log: $LG/loud.log"
lacks "verbose: no extra tail (it was streamed)" "  step 20"
rg install noisy; rc "GUI: install" 0
has "GUI: the chatter is streamed" "compiling noisy..."
has "GUI: the markers are there" "#start noisy"
has "GUI: ... and #progress" "#progress noisy 1/1"
eq "GUI: the log is written" 1 "$(grep -c '^compiling' "$LG/noisy.log")"
rg install loud; rc "GUI: failing build" 1
has "GUI: FAILED line is unchanged (no log suffix)" "loud: FAILED (install.sh exit 1)"
lacks "GUI: no log path on the FAILED line" "build log"
rgb 60 C '' install noisy; rc "quiet: pty install" 0
has "quiet: pty: the bar is on screen through the build, one frame per output line" "noisy: building -"
lacks "quiet: pty: the chatter is not printed" "compiling"
eq "quiet: pty: nothing but the lines to act on is left" "note: start it with: noisy --daemon
restart: noisy to use the new version
setup: do the thing
noisy: installed main $(git -C "$SRC/noisy" rev-parse --short HEAD)" "$(screen | grep -v '^$')"
rgb 60 C '' install loud; rc "quiet: pty failing build" 1
eq "quiet: pty failure: no bar is left" 0 "$(screen | grep -c '^\[')"
eq "quiet: pty failure: FAILED line, log tail and trailer are on screen" "1 1 1" "$(screen | awk '/^loud: FAILED .* build log: / { a = 1 } /^  oops/ { b = 1 } /^FAILED — nothing was installed/ { c = 1 } END { print a + 0, b + 0, c + 0 }')"
rgb 60 C '' install noisy --verbose; rc "verbose: pty" 0
has "verbose: pty: the chatter is streamed" "compiling noisy..."
lacks "verbose: pty: no bar (it would fight the stream)" "] 1/1"
has "verbose: pty: the status lines are printed instead" "noisy: building"
rgn remove noisy loud >/dev/null
RITZ_GET_MANIFEST=$T/programs; export RITZ_GET_MANIFEST

# ---- config: dir= ----------------------------------------------------------------------
mkdir -p "$XDG_CONFIG_HOME/ritz-get"
printf 'foo=bar\ndir=%s\nshortcuts=/nowhere\n' "$T/custom" >"$XDG_CONFIG_HOME/ritz-get/config"
rg install alpha; rc "install into dir=" 0
exists "dir= from the config is used" "$T/custom/alpha/.git"; gone "default folder untouched" "$SRC/alpha"
rg remove alpha >/dev/null
rm "$XDG_CONFIG_HOME/ritz-get/config"


# ---- D49: data: lines, remove keeps data, delete-data ----------------------------------
cat >"$T/pd" <<'EOF'
alpha t/alpha "Alpha program"
  data: ~/.config/alpha
  data: ~/.local/share/alpha/
  data: ~/.alpharc
  data: /etc
  data: ~/../x
  data: ~
  data: ~/.local/bin/x
  data: ~/.config/ritz-get
  data: ~/.config
  data: ~/.local/share
  data: ~/a/../b
omega t/omega-repo "Omega Title"
  data: ~/.config/omega
beta t/beta "Beta helper"
  data: ~/.config/blink
  data: ~/.config/viaparent/x
  data: ~/.local/state/beta
[Websites]
site https://example.com/page "A site"
  data: ~/.config/site
EOF
RITZ_GET_MANIFEST=$T/pd; export RITZ_GET_MANIFEST
KEEP=$HOME/.config/alpha-sibling
mkdir -p "$HOME/.config/alpha" "$HOME/.local/share/alpha" "$KEEP" "$HOME/.config/site"
echo x >"$HOME/.config/alpha/f"; echo x >"$HOME/.local/share/alpha/f"; echo x >"$HOME/.alpharc"; echo x >"$KEEP/f"
rg list --offline --porcelain --data; rc "D49: list with data: lines" 0
for w in '"/etc"' '"~/../x"' '"~"' '"~/.local/bin/x"' '"~/.config/ritz-get"' '"~/.config"' '"~/.local/share"' '"~/a/../b"'; do
	has "D49: bad data path warned: $w" "alpha: ignoring data path $w"
done
eq "D49: exactly the bad lines are warned about" 8 "$(grep -c 'ignoring data path' "$T/err")"
eq "D49: porcelain D records: existing paths only, ~ form, KB" "$(printf 'D\talpha\t~/.config/alpha\t%s\nD\talpha\t~/.local/share/alpha\t%s\nD\talpha\t~/.alpharc\t%s' \
	"$(du -sk "$HOME/.config/alpha" | cut -f1)" "$(du -sk "$HOME/.local/share/alpha" | cut -f1)" "$(du -sk "$HOME/.alpharc" | cut -f1)")" "$(grep '^D' "$T/out")"
eq "D49: D records follow their E record" "E D D D" "$(awk -F'\t' '$1 == "E" && $3 == "alpha" { printf "E"; for (i = 0; i < 3; i++) { getline; printf " %s", $1 } }' "$T/out")"
eq "D49: a website has no D records" 0 "$(grep -c '^D.site' "$T/out")"
eq "D49: porcelain E records keep 17 fields" 0 "$(awk -F'\t' '$1 == "E" && NF != 17' "$T/out" | wc -l | tr -d ' ')"
grep -v '^D' "$T/out" >"$T/with-data"
rg list --offline --porcelain; rc "D49: list --porcelain without --data" 0
eq "D49: without --data there is no D record" 0 "$(grep -c '^D' "$T/out")"
eq "D49: without --data the output is byte-identical to the old one" "$(cat "$T/with-data")" "$(cat "$T/out")"
printf 'alpha t/alpha "A"\n  data: ~/.config/a\tb\n  data:\t~/.config/ok\n  data: ~/.config/x\037y\n' >"$T/pd2"
rge RITZ_GET_MANIFEST="$T/pd2" list --offline --porcelain --data
eq "D49: a data: path with a tab (or a US) is rejected, a tab after 'data:' is not" 2 "$(grep -c 'ignoring data path' "$T/err")"
mkdir -p "$HOME/.config/ok"; rge RITZ_GET_MANIFEST="$T/pd2" list --offline --porcelain --data; rmdir "$HOME/.config/ok"
eq "D49: tab after 'data:' is only a separator" 1 "$(grep -c '^D.alpha.~/.config/ok.[0-9]' "$T/out")"
rm "$HOME/.alpharc"
rg list --offline --porcelain --data; eq "D49: a path that does not exist gets no D record" 2 "$(grep -c '^D.alpha' "$T/out")"
rg list --offline alpha; has "D49: human list, offline: data left" "not installed (offline), data left"
rg list alpha; has "D49: human list: data left" "not installed, data left"
rg list beta; lacks "D49: human list: no data, no remark" "data left"
rg install alpha >/dev/null; rg list --porcelain --data alpha
eq "D49: porcelain: installed programs get D records too" 2 "$(grep -c '^D.alpha' "$T/out")"
rg list alpha; lacks "D49: human list: installed, no 'data left'" "data left"
rg delete-data alpha; rc "D49: delete-data while installed" 1
has "D49: delete-data while installed: message" "alpha: FAILED (uninstall first: ritz-get remove alpha)"
exists "D49: installed: data untouched" "$HOME/.config/alpha/f"
rg remove alpha; rc "D49: remove" 0
has "D49: remove prints the hint" "alpha: data kept in ~/.config/alpha, ~/.local/share/alpha (delete with: ritz-get delete-data alpha)"
exists "D49: remove keeps the data" "$HOME/.config/alpha/f"; exists "D49: remove keeps the data (2)" "$HOME/.local/share/alpha/f"
rg remove beta; lacks "D49: remove without data: no hint" "data kept"
rg delete-data alpha; rc "D49: GUI=1, no --yes: no prompt, nothing deleted" 0
has "D49: GUI=1: says nothing was deleted" "alpha: nothing deleted (pass --yes)"; lacks "D49: GUI=1: no question" "Type the repository name"
has "D49: GUI=1: #start line" "#start alpha"; has "D49: GUI=1: #progress line" "#progress alpha 1/1"
rg delete-data alpha site; has "D49: GUI=1: two names, M = 2" "#progress site 2/2"
has "D49: delete-data lists the paths with sizes" "~/.config/alpha"
exists "D49: GUI=1 no --yes: data kept" "$HOME/.config/alpha/f"
printf 'y\n' | RITZ_GET_GUI=1 timeout 60 script -qec "sh '$RG' delete-data alpha" /dev/null >"$T/out" 2>"$T/err"; done_run
lacks "D49: GUI=1 on a terminal never prompts" "Type the repository name"; exists "D49: GUI=1 on a terminal: nothing deleted" "$HOME/.config/alpha/f"
rgn delete-data alpha; rc "D49: no tty, no --yes" 0
has "D49: no tty: nothing deleted" "alpha: nothing deleted (pass --yes)"; lacks "D49: no tty: no question" "Type the repository name"; exists "D49: no tty: data kept" "$HOME/.config/alpha/f"
rgt 'n
' delete-data alpha; rc "D49: tty, answer n" 0
has "D49: the warning" "All of alpha's config and data listed above will be deleted for good."; has "D49: the question" "Type the repository name (alpha) to confirm:"; has "D49: answer n aborts" "aborted"; exists "D49: answer n: data kept" "$HOME/.config/alpha/f"
rgt '
' delete-data alpha; rc "D49: tty, plain Enter = No" 0; exists "D49: Enter: data kept" "$HOME/.config/alpha/f"
rgt 'y
' delete-data alpha; rc "D49: tty, answer y" 0
has "D49: answer y aborts" "aborted"; exists "D49: y: data kept" "$HOME/.config/alpha/f"
rgt 'Alpha program
' delete-data alpha; has "D49: the display title aborts" "aborted"; exists "D49: title: data kept" "$HOME/.config/alpha/f"
rgt 'ALPHA
' delete-data alpha; has "D49: case differs: aborts" "aborted"; exists "D49: case: data kept" "$HOME/.config/alpha/f"
rgt 'alpha 
' delete-data alpha; has "D49: trailing space: aborts" "aborted"; exists "D49: space: data kept" "$HOME/.config/alpha/f"
mkdir -p "$HOME/.config/omega"; echo x >"$HOME/.config/omega/f"
rgt 'omega
' delete-data omega; has "D49: manifest name is not the repo name: aborts" "aborted"; exists "D49: name != repo: data kept" "$HOME/.config/omega/f"
has "D49: prompt shows the repo basename" "Type the repository name (omega-repo) to confirm:"
rgt 'omega-repo
' delete-data omega; has "D49: the repo name deletes" "omega: data deleted"; gone "D49: repo name: dir gone" "$HOME/.config/omega"
rgt 'alpha
' delete-data alpha; rc "D49: tty, exact repo name" 0
has "D49: exact name deletes" "alpha: data deleted"; gone "D49: name: first path gone" "$HOME/.config/alpha"; gone "D49: name: second path gone" "$HOME/.local/share/alpha"
exists "D49: a sibling of a declared path is left alone" "$KEEP/f"
rg delete-data alpha; rc "D49: nothing left" 0; has "D49: nothing left: message" "alpha: no data left"
mkdir -p "$HOME/.config/alpha"; echo x >"$HOME/.alpharc"
rg delete-data alpha --yes; rc "D49: --yes" 0; has "D49: --yes deletes" "alpha: data deleted"
gone "D49: --yes: dir gone" "$HOME/.config/alpha"; gone "D49: --yes: file gone" "$HOME/.alpharc"; exists "D49: --yes: sibling left alone" "$KEEP/f"
rg list --offline --porcelain --data; eq "D49: no data, no D records" 0 "$(grep -c '^D' "$T/out")"
rg delete-data site --yes; rc "D49: website" 0; has "D49: website message" "site: a website has no data"; exists "D49: website: a data: line on it is ignored" "$HOME/.config/site"
rg delete-data nope --yes; rc "D49: unknown name" 1; has "D49: unknown name text" "unknown program: nope"
rg delete-data; rc "D49: no name" 2
# symlinks and XDG mapping
mkdir -p "$T/outside" "$T/outside2" "$HOME/xs/beta" "$HOME/.local/state/beta"
echo x >"$T/outside/f"; echo x >"$T/outside2/x"; echo x >"$HOME/xs/beta/f"; echo x >"$HOME/.local/state/beta/f"
ln -s "$T/outside" "$HOME/.config/blink"; ln -s "$T/outside2" "$HOME/.config/viaparent"
rge XDG_STATE_HOME="$HOME/xs" list --porcelain --data beta; has "D49: XDG: D record keeps the ~ form" "$(printf 'D\tbeta\t~/.local/state/beta\t')"
rge XDG_STATE_HOME="$HOME/xs" delete-data beta --yes; rc "D49: symlink out of the home: one path refused" 1
has "D49: the refused path is named" "beta: not deleted: ~/.config/viaparent/x"
gone "D49: a symlinked data path is removed itself" "$HOME/.config/blink"; exists "D49: ... and its target is left alone" "$T/outside/f"
exists "D49: a path behind a symlinked parent is not followed" "$T/outside2/x"
gone "D49: XDG_STATE_HOME is honoured for ~/.local/state" "$HOME/xs/beta"; exists "D49: ... the plain ~/.local/state is left alone" "$HOME/.local/state/beta/f"
rm -f "$HOME/.config/viaparent"; rm -rf "$HOME/.local/state/beta"
rg list --porcelain --data beta; eq "D49: nothing left for beta" 0 "$(grep -c '^D' "$T/out")"
rm -rf "$HOME/xs"
# resolved paths: nothing in ritz-get's own folders, nothing outside the real $HOME
dd() { printf 'gamma t/gamma "G"\n  data: %s\n' "$1" >"$T/pd3"; RITZ_GET_MANIFEST=$T/pd3; }
dd '~/stuff/clone'; ln -s "$SRC" "$HOME/stuff"; mkdir -p "$SRC/clone/k"
rg delete-data gamma --yes; rc "D49: symlinked parent into the clone dir" 1
has "D49: ... refused by name" "gamma: not deleted: ~/stuff/clone"; exists "D49: ... the clone dir is untouched" "$SRC/clone/k"; lacks "D49: ... no 'data deleted'" "data deleted"
rg list --offline --porcelain --data gamma; eq "D49: ... and no D record is offered" 0 "$(grep -c '^D' "$T/out")"
rm -rf "$HOME/stuff" "$SRC/clone"
dd '~/lb/tool'; ln -s "$HOME/.local/bin" "$HOME/lb"; mkdir -p "$HOME/.local/bin/tool"
rg delete-data gamma --yes; rc "D49: symlinked parent into ~/.local/bin" 1
has "D49: ... refused" "gamma: not deleted: ~/lb/tool"; exists "D49: ... ~/.local/bin/tool untouched" "$HOME/.local/bin/tool"
rm -rf "$HOME/lb" "$HOME/.local/bin/tool"
dd '~/lc/cfgdir'; ln -s "$HOME/.config/ritz-get" "$HOME/lc"; mkdir -p "$HOME/.config/ritz-get/cfgdir"
rg delete-data gamma --yes; rc "D49: symlinked parent into the config dir" 1
has "D49: ... refused" "gamma: not deleted: ~/lc/cfgdir"; exists "D49: ... the config dir is untouched" "$HOME/.config/ritz-get/cfgdir"
rm -rf "$HOME/lc" "$HOME/.config/ritz-get/cfgdir"
dd '~/lk/kdir'; ln -s "$XDG_CACHE_HOME/ritz-get" "$HOME/lk"; mkdir -p "$XDG_CACHE_HOME/ritz-get/kdir"
rg delete-data gamma --yes; rc "D49: symlinked parent into the cache dir" 1
exists "D49: ... the cache dir is untouched" "$XDG_CACHE_HOME/ritz-get/kdir"
rm -rf "$HOME/lk" "$XDG_CACHE_HOME/ritz-get/kdir"
dd '~/ls'; ln -s "$HOME/.local/share" "$HOME/ls"; mkdir -p "$SRC/clone/k"
rg list --offline --porcelain --data gamma; eq "D49: ancestor via a symlink: no D record" 0 "$(grep -c '^D' "$T/out")"
rg list --offline gamma; lacks "D49: ... human list: no 'data left'" "data left"
rg delete-data gamma --yes; rc "D49: ancestor via a symlink: refused" 1
has "D49: ... refused by name" "gamma: not deleted: ~/ls"; exists "D49: ... the clone is untouched" "$SRC/clone/k"; exists "D49: ... and so is the link" "$HOME/ls"
rm -rf "$HOME/ls" "$SRC/clone"
# an XDG dir outside (or at, or above) the home is never used for the mapping
Q=$T/xq; mkdir -p "$Q/root/victim" "$HOME/.config/victim"; echo x >"$HOME/.config/victim/f"; echo x >"$Q/root/victim/f"
dd '~/.config/victim'
rge XDG_CONFIG_HOME="$Q/root" list --offline --porcelain --data gamma
eq "D49: XDG outside the home: the D record is the real ~/.config/victim" "$(printf 'D\tgamma\t~/.config/victim\t%s' "$(du -sk "$HOME/.config/victim" | cut -f1)")" "$(grep '^D' "$T/out")"
rge XDG_CONFIG_HOME="$Q/root" delete-data gamma --yes; rc "D49: XDG outside the home: delete-data" 0
exists "D49: ... the victim outside the home stays" "$Q/root/victim/f"; gone "D49: ... the one in the home is deleted" "$HOME/.config/victim"
mkdir -p "$HOME/.config/victim"
rge XDG_CONFIG_HOME=/ list --offline --porcelain --data gamma
eq "D49: XDG_CONFIG_HOME=/: the D record is ~/.config/victim" "D	gamma	~/.config/victim" "$(grep '^D' "$T/out" | cut -f1-3)"
rge XDG_CONFIG_HOME=/ delete-data gamma --yes; rc "D49: XDG_CONFIG_HOME=/: delete-data" 0; gone "D49: ... only the one in the home went" "$HOME/.config/victim"
mkdir -p "$HOME/.ssh" "$HOME/.config/.ssh"; echo x >"$HOME/.ssh/id"; dd '~/.config/.ssh'
rge XDG_CONFIG_HOME="$HOME" list --offline --porcelain --data gamma
eq "D49: XDG_CONFIG_HOME=\$HOME: no mapping, the D record is ~/.config/.ssh" "D	gamma	~/.config/.ssh" "$(grep '^D' "$T/out" | cut -f1-3)"
rge XDG_CONFIG_HOME="$HOME" delete-data gamma --yes; rc "D49: XDG_CONFIG_HOME=\$HOME: delete-data" 0
exists "D49: ... ~/.ssh stays" "$HOME/.ssh/id"; gone "D49: ... ~/.config/.ssh went" "$HOME/.config/.ssh"
mkdir -p "$T/victim2"; echo x >"$T/victim2/f"; dd '~/.config/victim2'
rge XDG_CONFIG_HOME="$HOME/.." list --offline --porcelain --data gamma
eq "D49: XDG_CONFIG_HOME=\$HOME/..: ignored, no D record" 0 "$(grep -c '^D' "$T/out")"
rge XDG_CONFIG_HOME="$HOME/.." delete-data gamma --yes; rc "D49: XDG_CONFIG_HOME=\$HOME/..: delete-data" 0; exists "D49: ... the dir above the home stays" "$T/victim2/f"
mkdir -p "$HOME/xc/victim3"; dd '~/.config/victim3'
rge XDG_CONFIG_HOME="$HOME/xc" list --offline --porcelain --data gamma
eq "D49: an XDG dir below the home still maps" "D	gamma	~/.config/victim3" "$(grep '^D' "$T/out" | cut -f1-3)"
rge XDG_CONFIG_HOME="$HOME/xc" delete-data gamma --yes; gone "D49: ... and deletes there" "$HOME/xc/victim3"
rm -rf "$HOME/xc" "$HOME/.ssh" "$T/victim2" "$Q"
# the shortcuts dirs: the default applications dir (other programs' launchers live there) is never data, whatever shortcuts= says
AP=$HOME/.local/share/applications; mkdir -p "$AP/keep"; echo x >"$AP/keep/f"
dd '~/.local/share/applications'
rg list --offline --porcelain --data gamma; eq "D49: the applications dir as data: no D record" 0 "$(grep -c '^D' "$T/out")"
has "D49: ... the line is warned about" "ignoring data path \"~/.local/share/applications\""
rg delete-data gamma --yes; lacks "D49: ... nothing deleted" "data deleted"; exists "D49: ... the other launchers survive" "$AP/keep/f"
dd '~/.local/share/applications/keep'
rg list --offline --porcelain --data gamma; eq "D49: a path inside the applications dir: no D record" 0 "$(grep -c '^D' "$T/out")"
dd '~/ap'; ln -s "$AP" "$HOME/ap"
rg delete-data gamma --yes; rc "D49: applications dir via a symlink: refused" 1
has "D49: ... refused by name" "gamma: not deleted: ~/ap"; exists "D49: ... the launchers survive" "$AP/keep/f"; exists "D49: ... and so does the link" "$HOME/ap"
dd '~/ap/keep'
rg delete-data gamma --yes; rc "D49: inside the applications dir via a symlink: refused" 1; exists "D49: ... keep survives" "$AP/keep/f"
rm -f "$HOME/ap"
# shortcuts= elsewhere: that dir is protected as well, and the default one still is
mkdir -p "$HOME/menu/k"; echo x >"$HOME/menu/k/f"; printf 'shortcuts=%s\n' "$HOME/menu" >"$XDG_CONFIG_HOME/ritz-get/config"
dd '~/menu'
rg list --offline --porcelain --data gamma; eq "D49: shortcuts= dir as data: no D record" 0 "$(grep -c '^D' "$T/out")"
has "D49: ... warned about" "ignoring data path \"~/menu\""
dd '~/menu/ritz-get-x.desktop'
rg list --offline --porcelain --data gamma; eq "D49: a path inside the shortcuts= dir: no D record" 0 "$(grep -c '^D' "$T/out")"
dd '~/.local/share/applications'
rg list --offline --porcelain --data gamma; eq "D49: shortcuts= elsewhere: the default applications dir is still no data" 0 "$(grep -c '^D' "$T/out")"
rg delete-data gamma --yes; exists "D49: ... its launchers survive" "$AP/keep/f"
dd '~/mn'; ln -s "$HOME/menu" "$HOME/mn"
rg delete-data gamma --yes; rc "D49: shortcuts= dir via a symlink: refused" 1
has "D49: ... refused by name" "gamma: not deleted: ~/mn"; exists "D49: ... the shortcuts= dir survives" "$HOME/menu/k/f"
dd '~/ap'; ln -s "$AP" "$HOME/ap"
rg delete-data gamma --yes; rc "D49: shortcuts= elsewhere: the default applications dir via a symlink: refused" 1; exists "D49: ... its launchers survive" "$AP/keep/f"
rm -rf "$HOME/mn" "$HOME/ap" "$HOME/menu" "$AP/keep"; rm -f "$XDG_CONFIG_HOME/ritz-get/config"
# a "." in dir= is normalised: the same folder written differently is still ritz-get's
mkdir -p "$HOME/foo/src/k"; echo x >"$HOME/foo/src/k/f"; printf 'dir=%s\n' "$HOME/foo/./src" >"$XDG_CONFIG_HOME/ritz-get/config"
dd '~/foo/./src'
rg list --offline --porcelain --data gamma; eq "D49: dir=~/foo/./src and data ~/foo/src: no D record" 0 "$(grep -c '^D' "$T/out")"
has "D49: ... warned about at parse time" "ignoring data path \"~/foo/./src\""
dd '~/fl/src'; ln -s "$HOME/foo" "$HOME/fl"
rg delete-data gamma --yes; rc "D49: ... through a symlinked parent: refused" 1
has "D49: ... refused by name" "gamma: not deleted: ~/fl/src"; exists "D49: ... the folder survives" "$HOME/foo/src/k/f"
printf 'dir=%s\n' "$HOME/foo//src/" >"$XDG_CONFIG_HOME/ritz-get/config"
rg delete-data gamma --yes; rc "D49: dir= with // and a trailing slash: refused too" 1; exists "D49: ... the folder survives too" "$HOME/foo/src/k/f"
rm -rf "$HOME/fl" "$HOME/foo"; rm -f "$XDG_CONFIG_HOME/ritz-get/config"
# rreal: "." and empty segments of the missing tail are dropped, ".." in it is an error
eval "$(sed -n '/^rreal() {/,/^}/p' "$RG")"; RH=$(readlink -f "$HOME")
eq "rreal: /./ in a missing tail is dropped" "$RH/nope/x" "$(rreal "$HOME/nope/./x")"
eq "rreal: // and a trailing / in a missing tail are dropped" "$RH/nope/x" "$(rreal "$HOME/nope//x/")"
eq "rreal: a ./ right after the existing part is dropped" "$RH/nope" "$(rreal "$HOME/./nope")"
eq "rreal: nothing missing: like readlink -f" "$RH" "$(rreal "$HOME/.")"
eq "rreal: the missing tail keeps its order" "$RH/a/b/c" "$(rreal "$HOME/a/./b/./c")"
rreal "$HOME/nope/../x" >/dev/null; eq "rreal: .. in a missing tail: rc 1" 1 "$?"
rreal "relative/x" >/dev/null; eq "rreal: a relative path: rc 1" 1 "$?"
# the parent swapped for a symlink between the check and the rm (a readlink shim does it right after the second check)
mkdir -p "$T/shim2" "$HOME/pdir/victim" "$T/outside3/victim"; echo x >"$HOME/pdir/victim/f"; echo x >"$T/outside3/victim/f"
cat >"$T/shim2/readlink" <<'EOF'
#!/bin/sh
out=$("$RACE_RL" "$@"); r=$?
printf '%s\n' "$out"
eval "last=\${$#}"
if [ "$last" = "$RACE_PARENT" ]; then
	n=$(cat "$RACE_CNT" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$RACE_CNT"
	[ "$n" -ne 2 ] || { mv "$RACE_PARENT" "$RACE_PARENT.moved" && ln -s "$RACE_OUT" "$RACE_PARENT"; }
fi
exit "$r"
EOF
chmod +x "$T/shim2/readlink"
RACE_RL=$(command -v readlink) RACE_PARENT=$HOME/pdir RACE_CNT=$T/race.cnt RACE_OUT=$T/outside3; export RACE_RL RACE_PARENT RACE_CNT RACE_OUT
dd '~/pdir/victim'
rge PATH="$T/shim2:$PATH" delete-data gamma --yes; rc "D49: parent swapped for a symlink before the rm: refused" 1
has "D49: ... reported as not deleted" "gamma: not deleted: ~/pdir/victim"; lacks "D49: ... no 'data deleted'" "data deleted"
eq "D49: ... the swap really happened" "$T/outside3" "$(readlink "$HOME/pdir")"
exists "D49: ... the data behind the new link is untouched" "$T/outside3/victim/f"; exists "D49: ... and so is the original" "$HOME/pdir.moved/victim/f"
unset RACE_RL RACE_PARENT RACE_CNT RACE_OUT; rm -rf "$T/shim2" "$T/race.cnt" "$HOME/pdir" "$HOME/pdir.moved" "$T/outside3"
# the human list only needs to know that data exists: no du
mkdir -p "$T/shim" "$HOME/.config/alpha"; echo x >"$HOME/.config/alpha/f"; RITZ_GET_MANIFEST=$T/pd
printf '#!/bin/sh\necho "$*" >>"%s"\nexec %s "$@"\n' "$T/du.calls" "$(command -v du)" >"$T/shim/du"; chmod +x "$T/shim/du"
rge PATH="$T/shim:$PATH" list --offline alpha; has "D49: du shim: the human list still says data left" "data left"
eq "D49: the human list does not call du" 0 "$(cat "$T/du.calls" 2>/dev/null | wc -l | tr -d ' ')"
rge PATH="$T/shim:$PATH" list --offline --porcelain --data alpha
eq "D49: list --porcelain --data calls du" 1 "$([ -s "$T/du.calls" ] && echo 1 || echo 0)"
rm -rf "$T/shim" "$T/du.calls" "$HOME/.config/alpha"
RITZ_GET_MANIFEST=$T/programs; export RITZ_GET_MANIFEST
echo
if [ "$F" -eq 0 ]; then echo "ALL PASS ($P checks)"; exit 0; fi
echo "$F FAILED ($P passed)"
exit 1
