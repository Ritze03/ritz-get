#!/bin/sh
# ritz-get spec v1 check: https://github.com/Ritze03/ritz-get/blob/main/SPEC.md
#
#   sh spec-check.sh REPO_DIR [TOOL...]   check a program repo. TOOL... = build tools to hide from PATH
#                                         for the exit-3 test (e.g. go, cargo, npm, pkg-config)
#   sh spec-check.sh                      self-test: checks fixtures built from template/install.sh
#                                         (run it from a ritz-get clone)
#
# One PASS/FAIL/SKIP line per check; a FAIL cites the SPEC rule (R1 ... R39). Last line: ALL PASS or
# "N FAILED". Exit 0 / 1. The repo is cloned into a temp dir, install.sh runs there in a throwaway
# HOME with stdin /dev/null, exactly as ritz-get calls it; your checkout and your real HOME are
# not touched. Toolchain caches (Go, Cargo, npm) stay in your real home so builds are fast.
# POSIX sh; needs git, od, find, sort, and mktemp. `timeout` is used if present.

fails=0 pre= HOOK=
ok()   { echo "PASS $1: $pre$2"; }
bad()  {   # paths in the temp world are shortened: $HOME/ -> ~/, the clone -> CLONE
	m=$2
	[ -z "${T:-}" ] || m=$(printf '%s' "$2" | sed "s|${C:-$T}|CLONE|g; s|$H/|~/|g; s|$T/||g")
	echo "FAIL $1: $pre$m"; fails=$((fails + 1))
}
skip() { echo "SKIP $1: $pre$2"; }

# ---------------------------------------------------------------------------------------------
# check_repo REPO_DIR [TOOL...]
# ---------------------------------------------------------------------------------------------
check_repo() {
	R=$1; shift; hide=$*
	here=$(pwd)
	R=$(cd "$R" 2>/dev/null && pwd -P) || { bad R1 "$R is not a directory"; return; }
	cd "$R" || return
	[ -f install.sh ] || { bad R1 "no install.sh at the repo root"; cd "$here"; return; }

	# ---- 1. static checks on the real checkout ------------------------------------------------
	if git ls-files -s install.sh 2>/dev/null | grep -q '^100755'; then ok R1 "install.sh is committed as executable (100755)"
	else bad R1 "install.sh is not in git as mode 100755 (git add it; git update-index --chmod=+x install.sh)"; fi
	[ "$(head -n 1 install.sh)" = '#!/bin/sh' ] && ok R2 "first line is #!/bin/sh" || bad R2 "first line of install.sh is not exactly #!/bin/sh"
	if sh -n install.sh 2>/dev/null; then ok R2 "sh -n install.sh"; else bad R2 "sh -n install.sh fails: $(sh -n install.sh 2>&1 | head -n 2)"; fi
	if command -v dash >/dev/null 2>&1; then
		dash -n install.sh 2>/dev/null && ok R2 "dash -n install.sh" || bad R2 "dash -n install.sh fails (bashism?)"
	fi
	head -n 5 install.sh | grep -qx '# ritz-get-spec: 1' && ok R3 "spec marker in the first 5 lines" \
		|| bad R3 "no line '# ritz-get-spec: 1' in the first 5 lines"
	NAME=$(sed -n 's/^NAME=\([^ 	#]*\).*/\1/p' install.sh | head -n 1 | tr -d "\"'")
	if printf '%s\n' "$NAME" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; then ok R4 "NAME=$NAME"
	else bad R4 "no valid NAME=... line in install.sh (found '$NAME')"; NAME=program; fi

	# icon.png: required, tracked, exactly 1024x1024 (PNG header read with od, no extra tools)
	if [ ! -f icon.png ]; then
		bad R5 "icon.png is missing. Do NOT create one: report 'waiting for icon.png' and stop (SPEC icon rule)"
	else
		git ls-files --error-unmatch icon.png >/dev/null 2>&1 && ok R5 "icon.png is tracked in git" || bad R5 "icon.png is not tracked in git (git add icon.png)"
		set -- $(od -An -tu1 -N8 icon.png)
		if [ "$*" = "137 80 78 71 13 10 26 10" ]; then
			set -- $(od -An -tu1 -j16 -N8 icon.png)
			w=$(($1 * 16777216 + $2 * 65536 + $3 * 256 + $4)); h=$(($5 * 16777216 + $6 * 65536 + $7 * 256 + $8))
			[ "$w" = 1024 ] && [ "$h" = 1024 ] && ok R5 "icon.png is a 1024x1024 PNG" || bad R5 "icon.png is ${w}x$h, it must be exactly 1024x1024. Do NOT resize or re-export it: report it"
		else bad R5 "icon.png is not a PNG file"; fi
	fi

	# the never-list, as far as grep can see it (comment lines ignored)
	code=$(grep -v '^[[:space:]]*#' install.sh)
	printf '%s\n' "$code" | grep -Eq '(^|[^[:alnum:]_$./-])(sudo|pkexec|su|doas)([[:space:]]|$)' \
		&& bad R37 "install.sh calls sudo/pkexec/su/doas directly: root only via \$RITZ_GET_SUDO (R33)" || ok R37 "no direct sudo/pkexec"
	printf '%s\n' "$code" | grep -Eq 'git[[:space:]]+(pull|fetch|checkout|reset|clean|stash|commit|merge|rebase)' \
		&& bad R37 "install.sh runs a git command that changes the clone" || ok R37 "no git commands that change the clone"
	printf '%s\n' "$code" | grep -Eq 'npm[[:space:]]+install|go[[:space:]]+mod[[:space:]]+tidy' \
		&& bad R6 "install.sh runs npm install / go mod tidy (rewrites tracked files; use npm ci)" || ok R6 "no npm install / go mod tidy"
	printf '%s\n' "$code" | grep 'cargo[[:space:]]\{1,\}build' | grep -qv -e '--locked' \
		&& bad R6 "cargo build without --locked (rewrites Cargo.lock)" || ok R6 "cargo builds use --locked"
	printf '%s\n' "$code" | grep -Eq '(share|SHARE_HOME|data)/applications' \
		&& bad R37 "install.sh writes into .../applications: start-menu shortcuts belong to ritz-get" || ok R37 "install.sh does not write start-menu entries"
	if [ -f "$NAME.desktop" ]; then
		if grep -q '^Type=Application' "$NAME.desktop" && grep -q '^Name=' "$NAME.desktop" && grep -q '^Exec=' "$NAME.desktop" \
			&& ! grep -q '^NoDisplay=true' "$NAME.desktop"; then ok R39 "$NAME.desktop has Type=Application, Name=, Exec="
		else bad R39 "$NAME.desktop needs Type=Application, Name=, Exec= and no NoDisplay=true"; fi
		if command -v desktop-file-validate >/dev/null 2>&1; then
			desktop-file-validate "$NAME.desktop" >/dev/null 2>&1 && ok R39 "desktop-file-validate $NAME.desktop" || bad R39 "desktop-file-validate $NAME.desktop: $(desktop-file-validate "$NAME.desktop" 2>&1 | head -n 2)"
		fi
	fi
	uses_root=
	if printf '%s\n' "$code" | grep -q '^ROOT_LINK='; then printf '%s\n' "$code" | grep -q '^ROOT_LINK=yes' && uses_root=1
	else printf '%s\n' "$code" | grep -q 'RITZ_GET_SUDO' && uses_root=1; fi

	# ---- 2. throwaway world: a clone of the repo plus uncommitted changes ---------------------
	T=$(mktemp -d) && T=$(cd "$T" && pwd -P) || { bad R6 "mktemp failed"; cd "$here"; return; }
	H=$T/home C=$T/src/$NAME SUDO= P=$PATH
	mkdir -p "$H" "$T/src" "$T/run"
	if ! git clone -q "$R" "$C" 2>"$T/clone.err"; then
		bad R6 "cannot clone $R (a git repo with at least one commit is needed): $(head -n 1 "$T/clone.err")"; cd "$here"; return
	fi
	git -C "$R" ls-files -mo --exclude-standard 2>/dev/null | tar -C "$R" -cf - -T - 2>/dev/null | tar -C "$C" -xf - 2>/dev/null
	base=$(git -C "$C" status --porcelain)
	TMO=$(command -v timeout || true); LIMIT=${SPEC_CHECK_TIMEOUT:-1800}
	# toolchain caches stay in the real home
	if command -v go >/dev/null 2>&1; then GOMODCACHE=$(go env GOMODCACHE 2>/dev/null) GOCACHE=$(go env GOCACHE 2>/dev/null); export GOMODCACHE GOCACHE; fi
	export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}" RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}" npm_config_cache="${npm_config_cache:-$HOME/.npm}"
	# a fake password helper for programs that use RITZ_GET_SUDO: checks the call shape, runs nothing
	cat > "$T/fakesudo" <<'EOF'
#!/bin/sh
log=$SPEC_SUDO_LOG
[ -z "${SPEC_SUDO_EXIT:-}" ] || { echo "called (exit $SPEC_SUDO_EXIT)" >> "$log"; exit "$SPEC_SUDO_EXIT"; }
{ [ "$1" = /bin/sh ] && [ "$2" = -c ] && [ "$4" = sh ]; } || { echo "BAD shape (want: /bin/sh -c SCRIPT sh ARGS): $*" >> "$log"; exit 0; }
s=$3; shift 4
rest=$(printf '%s' "$s" | sed -E 's/ln -sfn "\$[0-9]+" "\$[0-9]+"//g; s/rm -f "\$[0-9]+"//g; s/[ ;&]//g')
[ -z "$rest" ] || echo "BAD script (only ln -sfn / rm -f allowed): $s" >> "$log"
for a; do
	case $a in
	"$HOME"/*|/usr/local/bin/"$SPEC_NAME") ;;
	/*) echo "BAD path (only \$HOME and /usr/local/bin/NAME allowed): $a" >> "$log" ;;
	*) echo "BAD relative path: $a" >> "$log" ;;
	esac
done
echo "OK $s | $*" >> "$log"
EOF
	chmod +x "$T/fakesudo"

	# run LOG ARGS...: like ritz-get; result in $rc, output in $T/LOG.out and $T/LOG.err
	run() {
		l=$1; shift
		( cd "$C" || exit 99
		  unset DBUS_SESSION_BUS_ADDRESS
		  HOME=$H XDG_CONFIG_HOME=$H/xdg/config XDG_DATA_HOME=$H/xdg/data XDG_CACHE_HOME=$H/xdg/cache XDG_STATE_HOME=$H/xdg/state
		  XDG_RUNTIME_DIR=$T/run RITZ_GET_SPEC=1 RITZ_GET_SUDO=$SUDO NO_COLOR=1 TERM=dumb PATH=$P GIT_TERMINAL_PROMPT=0
		  SPEC_SUDO_LOG=$T/sudo.log SPEC_NAME=$NAME
		  export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_RUNTIME_DIR RITZ_GET_SPEC RITZ_GET_SUDO \
			NO_COLOR TERM PATH GIT_TERMINAL_PROMPT SPEC_SUDO_LOG SPEC_NAME
		  if [ -n "$TMO" ]; then exec "$TMO" "$LIMIT" ./install.sh "$@"; else exec ./install.sh "$@"; fi
		) </dev/null >"$T/$l.out" 2>"$T/$l.err"
		rc=$?
	}
	# files: every non-directory in the throwaway HOME, minus build-tool caches
	files() {
		find "$H" \( -path "$H/go" -o -path "$H/.cargo" -o -path "$H/.rustup" -o -path "$H/.npm" -o -path "$H/.cache" \
			-o -path "$H/.config/go" -o -path "$H/xdg/config/go" -o -path "$H/xdg/cache" \) -prune -o ! -type d -print | sort
	}
	snap() { files | while read -r f; do if [ -L "$f" ]; then echo "$f -> $(readlink "$f")"; else echo "$f"; fi; done; }
	errtail() { tail -n 3 "$T/$1.err" 2>/dev/null | tr '\n' '|'; }
	timed_out() { [ "$rc" -eq 124 ] && { bad R10 "$1 timed out after ${LIMIT}s (waiting for input? a prompt with --yes?)"; return 0; }; return 1; }
	clean_out() {
		e=$(printf '\033'); cr=$(printf '\r')
		if grep -Eiq '\[y/n\]|\(y/n\)|\(--yes\)|proceed\?|continue\?' "$T/$1.out" "$T/$1.err"; then bad R10 "$1 prints a question although --yes was given"
		elif grep -q "$e" "$T/$1.out" "$T/$1.err" || grep -q "$cr" "$T/$1.out" "$T/$1.err"; then bad R28 "$1 output has escape codes or carriage returns"
		else ok R28 "$1: plain output, no questions"; fi
	}
	links_ok() {                                    # links_ok CLONE
		f=$(files | while read -r x; do
			if [ ! -L "$x" ]; then echo "$x (not a symlink)"
			else case $(readlink "$x") in "$1"/*) [ -e "$x" ] || echo "$x (dangling)" ;; *) echo "$x -> $(readlink "$x") (not into the clone)" ;; esac; fi
		done)
		[ -z "$f" ] && ok R13 "everything created outside the clone is a symlink into the clone" || bad R13 "outside the clone: $(echo "$f" | tr '\n' ';')"
		[ -L "$H/.local/bin/$NAME" ] && [ -x "$H/.local/bin/$NAME" ] && ok R12 "~/.local/bin/$NAME is a working symlink" || bad R12 "~/.local/bin/$NAME missing, not a symlink or not executable"
		stray=$(files | grep -E "^$H/(\.config|\.local/share)/" | grep -v "^$H/\.local/share/ritz-get/links/" || true)
		[ -z "$stray" ] && ok R14 "XDG_* honoured (nothing in ~/.config or ~/.local/share)" || bad R14 "ignores XDG_CONFIG_HOME/XDG_DATA_HOME: $(echo "$stray" | tr '\n' ';')"
	}
	git_clean() { [ "$(git -C "$C" status --porcelain)" = "$base" ] && ok R6 "$1: git status unchanged" || bad R6 "$1 changed git status; git-ignore build output (/build/): $(git -C "$C" status --porcelain | tr '\n' ';')"; }

	# ---- 3. arguments, remove when nothing is installed ---------------------------------------
	run u1 --bogus;                 [ $rc -eq 2 ] && ok R9 "unknown argument exits 2" || bad R9 "unknown argument exits $rc, want 2"
	run u2;                         [ $rc -eq 2 ] && ok R9 "no argument exits 2" || bad R9 "no argument exits $rc, want 2"
	run u3 --install --remove --yes; [ $rc -eq 2 ] && ok R9 "--install --remove exits 2" || bad R9 "--install --remove exits $rc, want 2"
	[ -z "$(files)" ] && ok R9 "usage errors change nothing" || bad R9 "a usage error created files: $(files | tr '\n' ';')"
	run rm0 --remove --yes
	if timed_out "--remove"; then :; elif [ $rc -eq 0 ]; then ok R23 "--remove with nothing installed exits 0"; else bad R23 "--remove with nothing installed exits $rc: $(errtail rm0)"; fi
	[ -z "$(files)" ] && ok R23 "--remove with nothing installed creates nothing" || bad R23 "--remove created files: $(files | tr '\n' ';')"

	# ---- 4. exit 3: hide the build tools, everything else stays on PATH ----------------------
	mkdir "$T/path"
	if [ -n "$hide" ]; then
		IFS=:; for d in $PATH; do [ -d "$d" ] && ln -s "$d"/* "$T/path/" 2>/dev/null; done; unset IFS
		for t in $hide; do rm -f "$T/path/$t"; done
		P=$T/path; run miss --install --yes; P=$PATH
		if timed_out "missing-tool run"; then :; elif [ $rc -eq 3 ]; then ok R25 "missing tool exits 3"; else bad R25 "hiding '$hide': exit $rc, want 3. $(errtail miss)"; fi
		badlines=$(grep '^missing:' "$T/miss.err" | grep -Ev '^missing: [^ ]+ \(try: ([a-z]+:[A-Za-z0-9+._,-]+)( [a-z]+:[A-Za-z0-9+._,-]+)*\)$' || true)
		if ! grep -q '^missing:' "$T/miss.err"; then bad R26 "no 'missing: TOOL (try: pacman:PKG dnf:PKG apt:PKG)' line on stderr"
		elif [ -n "$badlines" ]; then bad R26 "malformed missing line: $badlines"
		else ok R26 "missing: lines are well-formed"; fi
		for t in $hide; do grep -q "^missing: $t " "$T/miss.err" || bad R26 "no 'missing: $t (try: ...)' line, but $t was hidden"; done
		[ -z "$(files)" ] && ok R21 "exit 3 changed nothing" || bad R21 "exit 3 left files: $(files | tr '\n' ';')"
		git_clean "exit 3 run"
	else
		skip R21 "exit-3 test (no tool to hide; pass build tools after the repo path, e.g. sh spec-check.sh . go)"
	fi

	# ---- 5. programs that use root ------------------------------------------------------------
	if [ -n "$uses_root" ]; then
		run root4 --install --yes
		if timed_out "no-root run"; then :; elif [ $rc -eq 3 ]; then
			skip R34 "a build tool is missing here (exit 3), root checks skipped:$(grep '^missing:' "$T/root4.err" | tr '\n' ' ')"; uses_root=
		else
			[ $rc -eq 4 ] && ok R34 "root needed and RITZ_GET_SUDO empty: exit 4" || bad R34 "root needed, RITZ_GET_SUDO empty: exit $rc, want 4. $(errtail root4)"
			grep -q '^needs root:' "$T/root4.err" && ok R27 "needs root: line on stderr" || bad R27 "no 'needs root: ...' line on stderr"
			[ -z "$(files)" ] && ok R34 "exit 4 changed nothing" || bad R34 "exit 4 left files: $(files | tr '\n' ';')"
			git_clean "exit 4 run"
			SUDO=$T/fakesudo; : > "$T/sudo.log"
			SPEC_SUDO_EXIT=127; export SPEC_SUDO_EXIT; run root127 --install --yes
			if [ $rc -eq 4 ] && grep -q '^needs root:' "$T/root127.err"; then ok R36 "root helper exits 127: exit 4 with 'needs root:'"; else bad R36 "root helper exits 127: got exit $rc, want 4 with a 'needs root:' line"; fi
			SPEC_SUDO_EXIT=126; run root126 --install --yes
			if [ $rc -ne 0 ] && [ $rc -ne 4 ] && grep -qi 'cancelled' "$T/root126.err"; then ok R36 "root helper exits 126: prints 'cancelled', fails quietly"; else bad R36 "root helper exits 126: got exit $rc, want a non-zero exit (not 4) and a 'cancelled' line"; fi
			unset SPEC_SUDO_EXIT
			run rootrm --remove --yes
			[ $rc -eq 0 ] && [ -z "$(files)" ] && ok R23 "--remove cleans up after a cancelled root step" || bad R23 "--remove after a cancelled root step: exit $rc, left: $(files | tr '\n' ';')"
			: > "$T/sudo.log"
		fi
	fi

	# ---- 6. install, install again ------------------------------------------------------------
	run i1 --install --yes
	if timed_out "first install"; then :; elif [ $rc -eq 3 ]; then
		skip R17 "a build tool is missing here (exit 3), runtime checks skipped:$(grep '^missing:' "$T/i1.err" | tr '\n' ' ')"
		[ -z "$hide" ] && echo "     hint: install the tools above, or pass them as TOOL arguments only to test exit 3"
		finish_repo; return
	elif [ $rc -eq 0 ]; then ok R17 "first install exits 0"
	else bad R17 "first install exits $rc: $(errtail i1)"; fi
	clean_out i1; links_ok "$C"; git_clean "first install"
	s1=$(snap)
	if [ -n "$uses_root" ]; then
		if [ -s "$T/sudo.log" ] && ! grep -q '^BAD' "$T/sudo.log" && grep -qF "ln -sfn \"\$1\" \"\$2\" | $H/.local/share/ritz-get/links/$NAME /usr/local/bin/$NAME" "$T/sudo.log"; then
			ok R33 "one root call, /bin/sh -c 'ln -sfn ...' sh ARGS (only ln -sfn / rm -f, absolute paths)"
			ok R32 "system link /usr/local/bin/$NAME -> ~/.local/share/ritz-get/links/$NAME"
		else bad R33 "root call is not '/bin/sh -c ln -sfn ... sh STABLE_LINK /usr/local/bin/$NAME': $(cat "$T/sudo.log" 2>/dev/null | tr '\n' ';')"; fi
		[ "$(grep -c '^OK' "$T/sudo.log")" -eq 1 ] && ok R33 "one root call (one password prompt)" || bad R33 "more than one root call: $(grep -c '^OK' "$T/sudo.log")"
	fi
	run i2 --install --yes
	if timed_out "second install"; then :; elif [ $rc -eq 0 ]; then ok R17 "second install exits 0"; else bad R17 "second install exits $rc: $(errtail i2)"; fi
	clean_out i2; git_clean "second install"
	[ "$(snap)" = "$s1" ] && ok R17 "idempotent: same paths and link targets after the second install" || bad R17 "the second install changed the paths/links: $(snap | diff - - 2>/dev/null; echo)"
	if [ -n "$HOOK" ]; then $HOOK; fi

	# ---- 7. the repo folder moves, install again: every link must follow ----------------------
	mkdir -p "$T/moved"; mv "$C" "$T/moved/$NAME"; C=$T/moved/$NAME
	run i3 --install --yes
	if timed_out "install after move"; then :; elif [ $rc -eq 0 ]; then ok R15 "install after the repo folder moved exits 0"; else bad R15 "install after the repo folder moved exits $rc: $(errtail i3)"; fi
	links_ok "$C"
	[ -z "$(readlink "$H/.local/bin/$NAME" | grep -v "^$C/")" ] && ok R15 "links follow the moved clone" || bad R15 "~/.local/bin/$NAME still points to the old folder (use ln -sfn with pwd -P, every run)"

	# ---- 8. remove: no build tools, config survives, nothing is left, twice ------------------
	mkdir -p "$H/xdg/config/$NAME" "$H/xdg/data/$NAME"; echo x > "$H/xdg/config/$NAME/settings"; echo x > "$H/xdg/data/$NAME/data"
	[ -n "$hide" ] && P=$T/path
	run rm1 --remove --yes; P=$PATH
	if timed_out "--remove"; then :; elif [ $rc -eq 0 ]; then ok R24 "--remove exits 0${hide:+ with $hide hidden}"; else bad R24 "--remove exits $rc (it must not need build tools): $(errtail rm1)"; fi
	clean_out rm1
	[ -f "$H/xdg/config/$NAME/settings" ] && [ -f "$H/xdg/data/$NAME/data" ] && ok R22 "config and user data survive --remove" || bad R22 "--remove deleted config or user data"
	rm -rf "$H/xdg/config/$NAME" "$H/xdg/data/$NAME"
	[ -z "$(files)" ] && ok R22 "nothing left behind after --remove" || bad R22 "left behind after --remove: $(files | while read -r x; do [ -L "$x" ] && echo "$x -> $(readlink "$x")" || echo "$x"; done | tr '\n' ';')"
	run rm2 --remove --yes; [ $rc -eq 0 ] && ok R23 "second --remove exits 0" || bad R23 "second --remove exits $rc"
	# partly installed: the command link is gone, the rest must still be removed
	run i4 --install --yes; rm -f "$H/.local/bin/$NAME"
	run rm3 --remove --yes
	if [ $rc -eq 0 ] && [ -z "$(files)" ]; then ok R23 "--remove of a partly installed program exits 0 and cleans up"; else bad R23 "--remove of a partly installed program: exit $rc, left: $(files | tr '\n' ';')"; fi
	finish_repo
}

finish_repo() {
	if [ $fails -gt 0 ]; then echo "     logs kept in $T"; else chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"; fi
	cd "$here"
}

# ---------------------------------------------------------------------------------------------
# self-test: fixtures built from template/install.sh
# ---------------------------------------------------------------------------------------------
mkpng() {   # a 1024x1024 PNG header (signature + IHDR + IEND); a test fixture only, it does not decode
	printf '\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\004\000\000\000\004\000\010\006\000\000\000\177\035\053\203\000\000\000\000IEND\256\102\140\202' > "$1"
}

# fixture NAME VARIANT: creates $S/NAME as a git repo; the per-program section comes from $S/NAME.sec
fixture() {
	d=$S/$1; mkdir -p "$d"
	awk -v sec="$S/$1.sec" '
		/^# ---- per-program section/ { print; while ((getline l < sec) > 0) print l; skip = 1; next }
		/^# ---- end per-program section/ { skip = 0 }
		!skip' "$tpl" > "$d/install.sh"
	chmod +x "$d/install.sh"
	mkpng "$d/icon.png"
	printf '/build/\n/dist/\n' > "$d/.gitignore"
	[ -f "$S/$1.extra" ] && cp "$S/$1.extra" "$d/$1.desktop"
	( cd "$d" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -q -m fixture )
}

svc_hook() {   # R20: an update must not bring back an autostart entry the user removed
	rm -f "$H/xdg/config/autostart/$NAME.desktop"
	run upd --install --yes
	if [ $rc -eq 0 ] && [ ! -e "$H/xdg/config/autostart/$NAME.desktop" ] && [ -L "$H/xdg/config/systemd/user/$NAME.service" ]; then
		ok R20 "update keeps the user's autostart opt-out and refreshes the unit"
	else bad R20 "update after removing the autostart entry: exit $rc, autostart back? $(ls "$H/xdg/config/autostart" 2>&1 | tr '\n' ' ')"; fi
	grep -q '^restart:' "$T/upd.out" && ok R30 "update prints a 'restart:' hint" || bad R30 "update prints no 'restart: ...' line"
}
swap_hook() {  # P3: repeated builds keep at most the current and the previous directory
	run s1 --install --yes; run s2 --install --yes
	n=$(ls -d "$C"/build/app-* 2>/dev/null | wc -l)
	[ "$n" -le 2 ] && [ "$n" -ge 1 ] && [ -x "$H/.local/bin/$NAME" ] && ok R18 "directory swap keeps $n app dir(s) and a working command" || bad R18 "directory swap left $n app dirs"
}

selftest() {
	here=$(cd "$(dirname "$0")" && pwd -P)
	tpl=$here/../template/install.sh
	[ -f "$tpl" ] || { echo "FAIL R1: template/install.sh not found (run the self-test from a ritz-get clone)"; echo "1 FAILED"; exit 1; }
	S=$(mktemp -d) && S=$(cd "$S" && pwd -P) || exit 1
	mkdir "$S/bin"
	# a build tool and a pkg-config the fixtures need (a fake pkg-config knows one library)
	printf '#!/bin/sh\nprintf "#!/bin/sh\\necho fixture\\n"\n' > "$S/bin/ritz-fixture-tool"
	printf '#!/bin/sh\n[ "$1" = --exists ] && [ "$2" = ritz-fixture-lib ]\n' > "$S/bin/pkg-config"
	chmod +x "$S/bin/ritz-fixture-tool" "$S/bin/pkg-config"
	PATH=$S/bin:$PATH; export PATH

	# --- basic: the template as it is, with a trivial build
	cat > "$S/basic.sec" <<'EOF'
NAME=ritzfixbasic
TARGET=build/$NAME
ROOT_LINK=no
check_tools() { need ritz-fixture-tool pacman:fixture dnf:fixture apt:fixture; need_pc ritz-fixture-lib pacman:l dnf:l,m apt:l; }
build() {
	ritz-fixture-tool > "build/.$NAME.new"
	chmod +x "build/.$NAME.new"
	mv -f "build/.$NAME.new" "build/$NAME"
}
install_files() { link "$dir/$TARGET" "$bin/$NAME"; }
remove_files() { unlink_ours "$bin/$NAME"; }
EOF
	# --- service: patterns P4 (autostart) and P5 (systemd user unit), plus NAME.desktop
	cat > "$S/service.sec" <<'EOF'
NAME=ritzfixsvc
TARGET=build/$NAME
ROOT_LINK=no
check_tools() { need ritz-fixture-tool pacman:fixture dnf:fixture apt:fixture; }
build() {
	ritz-fixture-tool > "build/.$NAME.new"
	chmod +x "build/.$NAME.new"
	mv -f "build/.$NAME.new" "build/$NAME"
}
unit=$cfg/systemd/user/$NAME.service
has_manager() { systemctl --user show-environment >/dev/null 2>&1; }
install_files() {
	link "$dir/$TARGET" "$bin/$NAME"
	# P4: generated autostart entry, linked out; first install only, later only if it still exists
	cat > build/.autostart.new <<EOT
[Desktop Entry]
Type=Application
Name=$NAME
Exec=$bin/$NAME --daemon
Icon=$dir/icon.png
NoDisplay=true
EOT
	mv -f build/.autostart.new build/autostart.desktop
	a=$cfg/autostart/$NAME.desktop
	if [ -n "$first" ] || [ -L "$a" ]; then link "$dir/build/autostart.desktop" "$a"; fi
	if [ -z "$first" ]; then echo "restart: $NAME to use the new version"
	else echo "note: start it with: $NAME --daemon"; fi
	# P5: generated unit, linked out with a plain ln; the manager is only touched when reachable
	cat > build/.unit.new <<EOT
[Unit]
Description=$NAME daemon

[Service]
ExecStart=%h/.local/bin/$NAME --daemon
Restart=on-failure

[Install]
WantedBy=default.target
EOT
	mv -f build/.unit.new "build/$NAME.service"
	if [ -n "$first" ] || [ -L "$unit" ]; then link "$dir/build/$NAME.service" "$unit"; fi
	if has_manager; then
		if [ -n "$first" ]; then
			systemctl --user daemon-reload && systemctl --user enable --now "$NAME.service" \
				|| echo "restart: the service did not start; run: systemctl --user enable --now $NAME.service"
		else
			systemctl --user daemon-reload && systemctl --user try-restart "$NAME.service" \
				|| echo "restart: run: systemctl --user restart $NAME.service"
		fi
	elif [ -n "$first" ]; then echo "restart: no systemd user session; later run: systemctl --user enable --now $NAME.service"
	else echo "restart: $NAME to use the new version"; fi
}
remove_files() {
	if has_manager; then systemctl --user disable --now "$NAME.service" 2>/dev/null || true; fi
	unlink_ours "$cfg/systemd/user/default.target.wants/$NAME.service"
	unlink_ours "$unit"
	if has_manager; then systemctl --user daemon-reload || true; fi
	unlink_ours "$cfg/autostart/$NAME.desktop"
	unlink_ours "$bin/$NAME"
}
EOF
	printf '[Desktop Entry]\nType=Application\nName=Fixture\nExec=ritzfixsvc %%U\nCategories=Utility;\n' > "$S/service.extra"
	# --- dirswap: pattern P3 (a directory output, swapped through a symlink)
	cat > "$S/dirswap.sec" <<'EOF'
NAME=ritzfixdir
TARGET=build/current/$NAME
ROOT_LINK=no
check_tools() { need ritz-fixture-tool pacman:fixture dnf:fixture apt:fixture; }
build() {
	mkdir -p dist/unpacked
	ritz-fixture-tool > "dist/unpacked/$NAME"; chmod +x "dist/unpacked/$NAME"
	prev=$(readlink build/current 2>/dev/null || true)
	new=app-$(date +%s)-$$
	cp -a dist/unpacked "build/$new"
	ln -sfn "$new" build/.current.new && mv -fT build/.current.new build/current
	for d in build/app-*; do
		case ${d#build/} in "$new"|"$prev") ;; *) rm -rf "$d" ;; esac
	done
}
install_files() { link "$dir/$TARGET" "$bin/$NAME"; }
remove_files() { unlink_ours "$bin/$NAME"; }
EOF
	# --- root: pattern P6 (the template's ROOT_LINK=yes)
	sed -e 's/^NAME=ritzfixbasic/NAME=ritzfixroot/' -e 's/^ROOT_LINK=no/ROOT_LINK=yes/' "$S/basic.sec" > "$S/root.sec"

	for v in basic service dirswap root; do
		case $v in basic) n=ritzfixbasic ;; service) n=ritzfixsvc ;; dirswap) n=ritzfixdir ;; root) n=ritzfixroot ;; esac
		mkdir -p "$S/repos"
		cp "$S/$v.sec" "$S/$n.sec"; [ -f "$S/$v.extra" ] && cp "$S/$v.extra" "$S/$n.extra"
		fixture "$n" "$v"
		pre="[$v] "; HOOK=
		[ "$v" = service ] && HOOK=svc_hook
		[ "$v" = dirswap ] && HOOK=swap_hook
		hide_set="ritz-fixture-tool"; [ "$v" = basic ] && hide_set="ritz-fixture-tool pkg-config"
		check_repo "$S/$n" $hide_set
		pre=; HOOK=
	done
	if [ $fails -eq 0 ]; then rm -rf "$S"; else echo "     fixtures kept in $S"; fi
}

# ---------------------------------------------------------------------------------------------
if [ $# -eq 0 ]; then selftest; else check_repo "$@"; fi
if [ $fails -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "$fails FAILED"; exit 1; fi
