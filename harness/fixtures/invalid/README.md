# Invalid (negative) test fixtures

These are **intentionally non-conformant** resources, kept here as raw JSON rather
than in the `et.fhir.core.test` IG. This mirrors the Zimbabwe reference kit
(`fhir-zw-lab-test-ig`, `karate/data/*-invalid.json`): SUSHI validates every FSH
`Instance` against its profile and **fails the IG build** on a cardinality
violation, so invalid resources cannot live in the IG as FSH. An IG also should
not *publish* non-conformant examples.

So the split is:
- **Valid** fixtures live in the IG (`et.fhir.core.test`, FSH examples) — SUSHI-clean,
  published, resolved by `run-tests.sh` from the IG package.
- **Invalid** fixtures live here — read directly by `run-tests.sh` and validated with
  `expectError = true`.

Each file declares its `meta.profile`, which is the profile it is validated against.
