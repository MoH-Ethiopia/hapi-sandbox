#!/usr/bin/env bash
# (Re)build the ET core IG package that HAPI loads, into ./igs/et.fhir.core.tgz
# (gitignored — it's a build artifact, not source).
#
# Source resolution (first match wins), overridable with ET_IG_SRC:
#   1) $ET_IG_SRC                              (a package/ dir OR an existing .tgz)
#   2) ~/.fhir/packages/et.fhir.core#dev       (local IG-publisher / sushi build cache)
#   3) ../ETBase-1/output/package.tgz          (sibling IG repo build output)
#
# LOCAL-DEV ONLY. Once et.fhir.core is published, skip this script entirely and
# set ET_IG_PACKAGE_URL=https://fhir.et/core/package.tgz in .env — HAPI fetches
# the published package directly and ./igs is unused.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root
OUT="igs/et.fhir.core.tgz"
mkdir -p igs

src="${ET_IG_SRC:-}"
if [ -z "$src" ]; then
  if [ -d "$HOME/.fhir/packages/et.fhir.core#dev/package" ]; then
    src="$HOME/.fhir/packages/et.fhir.core#dev"
  elif [ -f "../ETBase-1/output/package.tgz" ]; then
    src="../ETBase-1/output/package.tgz"
  fi
fi
[ -n "$src" ] || { echo "ERROR: no ET IG source found; set ET_IG_SRC to a package/ dir or .tgz" >&2; exit 1; }

if [ -f "$src" ]; then
  cp "$src" "$OUT"                              # already a .tgz
elif [ -d "$src/package" ]; then
  tar -czf "$OUT" -C "$src" package             # cache dir: tar the package/ subdir
elif [ -d "$src" ] && [ -f "$src/package.json" ]; then
  tar -czf "$OUT" -C "$(dirname "$src")" "$(basename "$src")"
else
  echo "ERROR: '$src' is neither a .tgz nor a package directory" >&2; exit 1
fi

name=$(tar -xzOf "$OUT" package/package.json | grep -oE '"name" *: *"[^"]*"' | head -1)
ver=$(tar -xzOf "$OUT" package/package.json | grep -oE '"version" *: *"[^"]*"' | head -1)
echo "Built $OUT from $src  ($name $ver)"
