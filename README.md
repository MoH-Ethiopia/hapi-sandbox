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

## Deploy (e.g. `sandbox.fhir.et`)

On a server with Docker, a public IP, and ports **80 + 443** open:

1. Point DNS: an `A` record `sandbox.fhir.et` → the server's IP.
2. Clone the repo, then set `.env`:
   ```ini
   DOMAIN=sandbox.fhir.et
   ACME_EMAIL=ops@fhir.et
   ```
   Leave `ET_IG_PACKAGE_URL` unset so it uses the published Ethiopia IG (no local build needed on the server).
3. `docker compose up -d`

Caddy automatically obtains a Let's Encrypt certificate for the domain. HAPI advertises
`https://sandbox.fhir.et/fhir` as its base URL, and CORS already allows `https://sandbox.fhir.et`.
Verify: `curl -sI https://sandbox.fhir.et/fhir/metadata` and open `https://sandbox.fhir.et/docs/`.

> The published Ethiopia IG keeps a fixed `0.9.0` version while it iterates, so to pick up a new
> build force a reload: `docker compose down && rm -rf data && docker compose up -d`.

## Using it
See the **[tutorial](docs/tutorial.html)** (served at `/docs/tutorial.html`) for validating
resources/bundles, the interceptor, Postman, and running a conformance session.

## Related
- [`ETBase`](https://moh-ethiopia.github.io/ETBase/) — the official Ethiopia Base IG (`et.fhir.core`).
- [`et.fhir.core.test`](https://github.com/pmanko/et.fhir.core.test) — conformance test fixtures.
