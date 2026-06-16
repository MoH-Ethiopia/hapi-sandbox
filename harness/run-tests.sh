#!/usr/bin/env bash
# Run the ET conformance validation suite against the sandbox.
#   ./run-tests.sh                      # validate vs http://localhost:8090/fhir
#   SHR_URL=https://host/fhir ./run-tests.sh
#
# Data-free: fixtures are resolved from the et.fhir.core.test IG package (see
# scripts/resolve-test-ig.sh) and validated against their ET profiles. Profile
# selection reuses interceptor/profileFor.json (a resource's meta.profile wins).
set -euo pipefail
cd "$(dirname "$0")"

KARATE_VERSION="${KARATE_VERSION:-2.0.3}"
JAR="karate-${KARATE_VERSION}.jar"
SHR_URL="${SHR_URL:-http://localhost:8090/fhir}"
mkdir -p target

[ -f "$JAR" ] || { echo "Downloading Karate ${KARATE_VERSION}..."; \
  curl -fL -o "$JAR" "https://github.com/karatelabs/karate/releases/download/v${KARATE_VERSION}/karate-${KARATE_VERSION}.jar"; }

PKG="$(scripts/resolve-test-ig.sh)"
echo "Fixtures from: $PKG"

# Build the fixture manifest from the IG package's example instances.
python3 - "$PKG" interceptor/profileFor.json > target/fixtures.json <<'PY'
import json, os, sys, glob
pkg, profile_map_file = sys.argv[1], sys.argv[2]
profiles = {k: v for k, v in json.load(open(profile_map_file)).items() if not k.startswith('_')}
SKIP = {'ImplementationGuide','CapabilityStatement','StructureDefinition','ValueSet',
        'CodeSystem','SearchParameter','OperationDefinition','Bundle'}
out = []
# Examples may be flat (sushi output) or under example/ (IG Publisher package).
files = glob.glob(os.path.join(pkg, '*.json')) + glob.glob(os.path.join(pkg, 'example', '*.json'))
for f in sorted(files):
    base = os.path.basename(f)
    if base == 'package.json':
        continue
    try:
        r = json.load(open(f))
    except Exception:
        continue
    rt = r.get('resourceType')
    if not rt or rt in SKIP:
        continue
    meta = (r.get('meta') or {}).get('profile') or []
    profile = meta[0] if meta else profiles.get(rt)
    name = r.get('id', base)
    expect_error = ('bad' in base.lower() or 'invalid' in base.lower()
                    or 'bad' in name.lower() or 'invalid' in name.lower())
    out.append({'name': name, 'file': os.path.abspath(f), 'resourceType': rt,
                'profile': profile, 'expectError': expect_error})
json.dump(out, sys.stdout, indent=2)
PY

echo "Fixtures to validate:"; python3 -c 'import json;[print("  -",x["name"],"(expectError="+str(x["expectError"])+")") for x in json.load(open("target/fixtures.json"))]'

java -Dshr="$SHR_URL" -Dfixtures="$PWD/target/fixtures.json" \
  -jar "$JAR" features/validate.feature
