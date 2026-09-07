# Recipes for this config. Every one is a single command, so they run the same
# under sh, cmd and PowerShell.

# List the recipes
default:
    @just --list

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
