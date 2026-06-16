# Ethiopia FHIR Validation Sandbox

A sandbox for validating FHIR resources against the **official Ethiopia FHIR specifications** —
the Ethiopia Base IG ([`et.fhir.core`](https://moh-ethiopia.github.io/ETBase/)). Submit a resource
or bundle and get a conformance verdict against the published Ethiopian profiles.

It runs a FHIR server (the validation engine, with the Ethiopia IG loaded), a TLS gateway, an
always-on conformance **interceptor**, and a small test harness.

## Quick start

```bash
cp .env.example .env          # defaults to DOMAIN=localhost
docker compose up -d
open https://localhost/docs/  # dashboard (self-signed locally — accept the cert)
```

By default the sandbox validates against the published Ethiopia IG dev build
(`https://moh-ethiopia.github.io/ETBase/`). `docker compose ps` should show all services healthy.

## Three ways to validate

1. **Interceptor** — `POST https://localhost/intercept` with a resource or transaction bundle.
   It validates against the Ethiopia profiles, returns the verdict in the `X-ET-Validation` header,
   and forwards to the server. Try it from the browser: `https://localhost/sim/simulator.html`.
2. **`$validate`** — `POST https://localhost/fhir/{Type}/$validate?profile=…` for a raw
   OperationOutcome. Ready-made requests are in `docs/postman/ET-FHIR-Showcase.postman_collection.json`.
3. **Batch** — `cd harness && ./run-tests.sh` validates a set of fixtures (valid must pass, invalid
   must fail).

Which Ethiopian profile a resource is checked against is taken from its own `meta.profile`.

## Routes
| Path | Purpose |
|---|---|
| `/fhir/*` | FHIR API (CRUD, search, `$validate`, `/metadata`) |
| `/validate`, `/validate/{Type}` | raw `$validate` (validate-only) |
| `/intercept` | conformance proxy (validate → forward) |
| `/docs/` | dashboard · `/sim/simulator.html` simulator |

## Session testing

```bash
cd harness
./test-session.sh          # live ✓/✗ feed; Ctrl+C → audit + HTML dashboard
```
Point a system (or the simulator) at `/intercept`, exercise it, then stop. The harness records every
verdict and audits what was stored against the Ethiopia profiles. Needs Java 17+ (`.sdkmanrc` pins
`21.0.5-tem`; run `sdk env`).

## Configuration (`.env`)
- `DOMAIN` — `localhost` (self-signed) or a public domain (auto HTTPS).
- `ET_IG_PACKAGE_URL` / `ET_IG_VERSION` — the Ethiopia IG to validate against. Defaults to the
  published dev build; set a `file:///igs/et.fhir.core.tgz` URL (built by
  `harness/scripts/refresh-core-ig.sh`) for offline use.

## Related
- [`ETBase`](https://moh-ethiopia.github.io/ETBase/) — the official Ethiopia Base IG (`et.fhir.core`).
- [`et.fhir.core.test`](https://github.com/pmanko/et.fhir.core.test) — conformance test fixtures.
