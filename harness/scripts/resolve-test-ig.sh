#!/usr/bin/env bash
# Resolve the et.fhir.core.test fixture package and print its package/ directory.
# This package holds the VALID fixtures; the intentionally-invalid (negative)
# ones live in the harness at fixtures/invalid/ (they can't be FSH examples — see
# fixtures/invalid/README.md).
#
# Resolution order (override with TEST_IG_DIR / TEST_IG_PKG_URL):
#   1. $TEST_IG_DIR                              a package/ dir
#   2. ~/.fhir/packages/et.fhir.core.test#*/package   local build cache
#   3. download the published dev build from GitHub Pages
set -euo pipefail
ID="et.fhir.core.test"
PKG_URL="${TEST_IG_PKG_URL:-https://pmanko.github.io/et.fhir.core.test/package.tgz}"

if [ -n "${TEST_IG_DIR:-}" ]; then echo "$TEST_IG_DIR"; exit 0; fi

for d in "$HOME/.fhir/packages/$ID#dev/package" "$HOME/.fhir/packages/$ID"#*/package; do
  [ -d "$d" ] && { echo "$d"; exit 0; }
done

cache="$(cd "$(dirname "$0")/.." && pwd)/target/test-ig"
mkdir -p "$cache"
curl -fsSL "$PKG_URL" -o "$cache/package.tgz"
rm -rf "$cache/package"
tar -xzf "$cache/package.tgz" -C "$cache"
echo "$cache/package"
