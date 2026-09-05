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
