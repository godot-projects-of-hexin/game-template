#!/usr/bin/env bash
# Single gate for the three pass criteria documented in agent.md (section 6)
# and addons/gd-common/agent.md (section 7.1).
#
# Usage, from the project root:
#   bash scripts/verify.sh
#   GODOT=/path/to/godot bash scripts/verify.sh
#
# Suites are discovered from disk, so adding a test_*.gd file automatically
# puts it behind the gate. Exit 0 means all three criteria passed.
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "error: '$GODOT' not found. Set GODOT=/path/to/godot and retry." >&2
	exit 127
fi
if [ ! -f "$PROJECT_DIR/project.godot" ]; then
	echo "error: no project.godot in '$PROJECT_DIR'." >&2
	exit 2
fi

failures=0
fail() {
	echo "FAIL: $1"
	failures=$((failures + 1))
}

# --- Criterion 1: global class cache must exist -----------------------------
# A fresh clone has no .godot/, so class_name types are unresolvable. This is
# also where new class_name declarations become visible.
echo "== [1/3] --import"
import_out="$("$GODOT" --headless --path "$PROJECT_DIR" --import 2>&1)"
import_code=$?
if [ "$import_code" -ne 0 ]; then
	fail "--import exited $import_code"
	echo "$import_out"
fi

# --- Criterion 2: startup must be clean ------------------------------------
echo "== [2/3] --quit"
quit_out="$("$GODOT" --headless --path "$PROJECT_DIR" --quit 2>&1)"
quit_code=$?
quit_errors=$(printf '%s' "$quit_out" | grep -Ec 'SCRIPT ERROR|ERROR:|Parse Error|Compile Error' || true)
quit_leaks=$(printf '%s' "$quit_out" | grep -Ec 'ObjectDB instances were leaked|resources still in use' || true)
if [ "$quit_code" -ne 0 ]; then
	fail "--quit exited $quit_code"
fi
if [ "$quit_errors" -ne 0 ]; then
	fail "--quit printed $quit_errors error line(s)"
fi
if [ "$quit_leaks" -ne 0 ]; then
	fail "--quit reported $quit_leaks leak line(s)"
fi
if [ "$quit_code" -ne 0 ] || [ "$quit_errors" -ne 0 ] || [ "$quit_leaks" -ne 0 ]; then
	echo "$quit_out"
fi

# --- Criterion 3: every suite must print "all passed" ----------------------
# Compile errors are fatal; plain ERROR:/WARNING: lines are expected in suites
# that deliberately exercise failure branches (see agent.md 7.1).
echo "== [3/3] test suites"
# A shallow checkout without submodules would silently skip all shared suites,
# leaving the project suite green. Refuse to pass in that state.
if [ ! -d "$PROJECT_DIR/addons/gd-common/tests" ]; then
	fail "addons/gd-common/tests missing — checkout the submodule (git submodule update --init --recursive)"
fi

suites=()
for f in "$PROJECT_DIR"/addons/gd-common/tests/test_*.gd; do
	[ -e "$f" ] && suites+=("addons/gd-common/tests/$(basename "$f" .gd)")
done
for f in "$PROJECT_DIR"/tests/test_*.gd; do
	[ -e "$f" ] && suites+=("tests/$(basename "$f" .gd)")
done

if [ "${#suites[@]}" -eq 0 ]; then
	fail "no test_*.gd suites found"
fi

for suite in "${suites[@]}"; do
	out="$("$GODOT" --headless --path "$PROJECT_DIR" --script "res://${suite}.gd" 2>&1)"
	code=$?
	script_errors=$(printf '%s' "$out" | grep -Ec 'SCRIPT ERROR|Parse Error|Compile Error' || true)
	# Shared suites carry a documented headless dummy-audio leak exception
	# (test_audio_manager); project suites are expected to be leak-free, and a
	# leak does not change the exit code, so it has to be checked explicitly.
	suite_leaks=0
	if [[ "$suite" == tests/* ]]; then
		suite_leaks=$(printf '%s' "$out" | grep -Ec 'ObjectDB instances were leaked|resources still in use' || true)
	fi
	if ! printf '%s' "$out" | grep -q 'all passed'; then
		fail "$suite did not print 'all passed'"
		echo "$out"
	elif [ "$script_errors" -ne 0 ]; then
		fail "$suite printed $script_errors compile/parse error(s)"
		echo "$out"
	elif [ "$code" -ne 0 ]; then
		fail "$suite exited $code"
		echo "$out"
	elif [ "$suite_leaks" -ne 0 ]; then
		fail "$suite reported $suite_leaks leak line(s) (project suites must be leak-free)"
		echo "$out"
	else
		printf '  ok  %s\n' "$suite"
	fi
done

echo
if [ "$failures" -gt 0 ]; then
	echo "GATE: FAILED ($failures problem(s))"
	exit 1
fi
echo "GATE: PASSED (${#suites[@]} suites, clean startup)"
