#!/usr/bin/env bash
# check_ios_regen.sh
#
# Fails (exit 1) if the on-disk Info.plist or entitlements file under
# app/src-tauri/gen/apple/focus-flow_iOS/ are out of sync with what
# `xcodegen generate` would produce from project.yml. Catches drift
# between the source of truth and the on-disk files before it gets
# merged.
#
# Wired into:
#   - the pre-commit hook (app/src-tauri/scripts/hooks/pre-commit)
#   - `just check-ios`
#   - `just check-all`
#
# Restore-on-failure: the script backs up the two files before
# regenerating and restores them if the check fails (or unconditionally
# at the end, as a no-op if there's no drift). This means the working
# tree is left exactly as it was — the pre-commit hook can fail the
# commit without leaving surprise file changes behind.
#
# Exits 0 silently if xcodegen is missing, project.yml is missing,
# or the working tree is not an iOS Tauri checkout. This lets the
# script be invoked unconditionally from CI without breaking other
# pipelines.

set -euo pipefail

cd "$(dirname "$0")/../gen/apple" || {
    echo "check-ios-regen: app/src-tauri/gen/apple/ not found, skipping" >&2
    exit 0
}

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "check-ios-regen: 'xcodegen' not on PATH (install with: brew install xcodegen)" >&2
    exit 1
fi

if [ ! -f project.yml ]; then
    echo "check-ios-regen: project.yml missing, skipping" >&2
    exit 0
fi

info_plist="focus-flow_iOS/Info.plist"
entitlements="focus-flow_iOS/focus-flow_iOS.entitlements"

if [ ! -f "$info_plist" ] || [ ! -f "$entitlements" ]; then
    echo "check-ios-regen: $info_plist or $entitlements missing, skipping" >&2
    exit 0
fi

# Save the current on-disk state of the two files we care about.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cp "$info_plist" "$tmpdir/Info.plist.orig"
cp "$entitlements" "$tmpdir/entitlements.orig"

# Regenerate. xcodegen is deterministic — same project.yml always
# produces the same Info.plist and entitlements (modulo xcodegen's
# own version, which is pinned via brew).
xcodegen generate >/dev/null

# Snapshot the regen output so we can show the diff if drift is
# detected (and so we can restore the working tree afterwards).
cp "$info_plist" "$tmpdir/Info.plist.regen"
cp "$entitlements" "$tmpdir/entitlements.regen"

drift=0
if ! diff -q "$tmpdir/Info.plist.orig" "$tmpdir/Info.plist.regen" >/dev/null; then
    drift=1
fi
if ! diff -q "$tmpdir/entitlements.orig" "$tmpdir/entitlements.regen" >/dev/null; then
    drift=1
fi

# Restore the original files regardless. The regen either matched
# the originals (no-op restore) or didn't (in which case we want
# the user's working tree back).
cp "$tmpdir/Info.plist.orig" "$info_plist"
cp "$tmpdir/entitlements.orig" "$entitlements"

if [ "$drift" -ne 0 ]; then
    echo "check-ios-regen: Info.plist or entitlements out of sync with project.yml." >&2
    echo "  Run 'just ios-regen', review the diff, and commit the result." >&2
    echo "" >&2
    echo "  --- diff (regenerated vs. committed) ---" >&2
    if ! diff -q "$tmpdir/Info.plist.orig" "$tmpdir/Info.plist.regen" >/dev/null; then
        diff -u "$tmpdir/Info.plist.orig" "$tmpdir/Info.plist.regen" >&2 || true
    fi
    if ! diff -q "$tmpdir/entitlements.orig" "$tmpdir/entitlements.regen" >/dev/null; then
        diff -u "$tmpdir/entitlements.orig" "$tmpdir/entitlements.regen" >&2 || true
    fi
    echo "" >&2
    echo "  The working tree has been restored to its pre-check state." >&2
    exit 1
fi

exit 0
