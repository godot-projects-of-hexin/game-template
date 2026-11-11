#!/usr/bin/env bash
# Run the project-layer regression suites from the project root.
#
# Usage:
#   bash tests/run_all.sh
#   GODOT=/path/to/godot bash tests/run_all.sh
set -u

GODOT="${GODOT:-godot}"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
SUITES=(
	test_project_core
	test_visual_style
)

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "error: '$GODOT' not found. Set GODOT=/path/to/godot and retry." >&2
	exit 127
fi

if [ ! -f "$PROJECT_DIR/project.godot" ]; then
	echo "error: no project.godot in '$PROJECT_DIR'." >&2
	echo "       Run this from the project root, or set PROJECT_DIR." >&2
	exit 2
fi

failed=0
for suite in "${SUITES[@]}"; do
	printf '>> %s\n' "$suite"
	if ! "$GODOT" --headless --path "$PROJECT_DIR" \
		--script "res://tests/${suite}.gd"; then
		failed=$((failed + 1))
	fi
done

echo
if [ "$failed" -gt 0 ]; then
	echo "RESULT: $failed suite(s) failed"
	exit 1
fi
echo "RESULT: all ${#SUITES[@]} suites passed"
