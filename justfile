# Recipes for this config. Every one is a single command, so they run the same
# under sh, cmd and PowerShell.

# On Windows just reaches for `sh`, which a plain PowerShell has no reason to
# have. Every recipe here is one plain command, so cmd runs them all.
set windows-shell := ["cmd.exe", "/c"]

# List the recipes
default:
    @just --list

# Walk through a first install: mpv, uosc, the patch, shaders, layout and AniList
first-run:
    python first-run.py

# Reapply the local patches over the vendored uosc, after installing or updating it
patch:
    python patches/apply.py

# Say what the patches would do, without writing anything
patch-check:
    python patches/apply.py --check

# Install the python packages the AniList scripts import, into a local vendor dir
setup:
    uv pip install --target portable_config/scripts/anilistUpdater/vendor -r portable_config/scripts/anilistUpdater/requirements.txt

# Check that those packages are importable the way mpv will import them
setup-check:
    python portable_config/scripts/anilistUpdater/anilistUpdater.py --deps
