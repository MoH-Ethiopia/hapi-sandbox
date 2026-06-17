#!/usr/bin/env bash
# Resolve the et.fhir.core.test repo's test-fixtures/ directory (negative
# resources + good/bad bundles) and print its path. These live in the test IG
# repo, OUTSIDE input/ (so the IG Publisher ships them without QA-validating
# them); this harness carries no fixtures of its own.
#
# Resolution order (override with TEST_IG_FIXTURES):
#   1. $TEST_IG_FIXTURES                     an existing test-fixtures/ dir
#   2. sibling checkout of et.fhir.core.test
#   3. shallow-clone the repo into target/test-ig-repo
set -euo pipefail

if [ -n "${TEST_IG_FIXTURES:-}" ]; then echo "$TEST_IG_FIXTURES"; exit 0; fi

here="$(cd "$(dirname "$0")/.." && pwd)"          # harness/
for d in "$here/../../et.fhir.core.test/test-fixtures" \
         "$HOME/code/et.fhir.core.test/test-fixtures"; do
  [ -d "$d" ] && { (cd "$d" && pwd); exit 0; }
done

REPO_URL="${TEST_IG_REPO_URL:-https://github.com/pmanko/et.fhir.core.test.git}"
dst="$here/target/test-ig-repo"
if [ ! -d "$dst/.git" ]; then
  rm -rf "$dst"; git clone --depth 1 "$REPO_URL" "$dst" >&2
else
  git -C "$dst" pull --ff-only >&2 || true
fi
echo "$dst/test-fixtures"
