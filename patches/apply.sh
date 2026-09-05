#!/usr/bin/env bash
# Reapply the local uosc patches. `portable_config/scripts/uosc/` is gitignored,
# so uosc's own updater silently reverts them: run this after every update.
set -euo pipefail

cd "$(dirname "$0")/.."

for patch in patches/*.patch; do
	# autocrlf would rewrite uosc's LF sources on apply, which turns the next
	# regenerated diff into a whole-file replacement
	git_apply() { git -c core.autocrlf=false apply "$@"; }
	if git_apply --check --reverse "$patch" 2>/dev/null; then
		echo "already applied: $patch"
	elif git_apply "$patch"; then
		echo "applied:         $patch"
	else
		echo "FAILED:          $patch" >&2
		exit 1
	fi
done
