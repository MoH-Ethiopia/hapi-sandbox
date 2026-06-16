# Ethiopia FHIR Validation Sandbox

A self-contained sandbox for **central FHIR conformance testing** against the Ethiopia Base IG
([`et.fhir.core`](https://moh-ethiopia.github.io/ETBase/)). It bundles a FHIR server, a TLS
gateway, an always-on conformance **interceptor**, and a **Karate** test harness with actor
simulators, a session dashboard, and an auditor.

> Scope: this repo owns the **test setup**. The HIV IG / profiling is owned elsewhere; the harness
> is IG-agnostic and validates whatever a resource declares (`meta.profile`) against the loaded IG.

## Architecture

```
                       Caddy ({$DOMAIN}, auto-TLS)
  /docs*       static  ->  showcase dashboard
  /sim*        static  ->  actor simulators
  /fhir/*      proxy   ->  HAPI            (STORAGE + $validate engine, et.fhir.core loaded)
  /validate*   proxy   ->  HAPI $validate  (raw, validate-only)
  /intercept/* proxy   ->  interceptor     (Karate mock: validate + record + forward)
```

- **HAPI FHIR** (`hapiproject/hapi`, distroless + a static busybox for the healthcheck) — stores
  resources and is the `$validate` engine. Loads `et.fhir.core` via `hapi.fhir.implementationguides`.
- **interceptor** — a Karate *mock* acting as a pass-through conformance proxy: validates a POSTed
  resource or transaction Bundle, records the verdict + seen patients, then forwards to HAPI and
  returns the response with `X-ET-Validation` / `X-ET-Validation-Report` headers.
- **Caddy** — the only public listener; automatic HTTPS (Let's Encrypt for a real domain, internal
  CA for `localhost`).

## Quick start (local)

```bash
cp .env.example .env          # defaults: DOMAIN=localhost
docker compose up -d          # HAPI + interceptor + Caddy
open https://localhost/docs/  # showcase dashboard (self-signed cert -> accept / curl -k)
```

Direct HAPI (no TLS) is on `http://localhost:8090/fhir`. `docker compose ps` should show all three
services healthy.

### Configuration (`.env`)
- `DOMAIN` — `localhost` (internal CA) or a public FQDN (Let's Encrypt).
- `ACME_EMAIL` — Let's Encrypt contact (deployed only).
- `ET_IG_PACKAGE_URL` / `ET_IG_VERSION` — IG source. **Default: the published dev build**
  (`https://moh-ethiopia.github.io/ETBase/package.tgz`, `0.9.0`). For an offline build, set
  `ET_IG_PACKAGE_URL=file:///igs/et.fhir.core.tgz` + `ET_IG_VERSION=dev` and run
  `harness/scripts/refresh-core-ig.sh`.

## Routes / endpoints
| Path | Goes to | Use |
|---|---|---|
| `/fhir/*` | HAPI | full FHIR API (CRUD, search, `$validate`, `/metadata`) |
| `/validate`, `/validate/{Type}` | HAPI `$validate` | raw validation (validate-only) |
| `/intercept` | interceptor | **conformance proxy**: validate → record → forward |
| `/docs/` | static | showcase dashboard |
| `/sim/simulator.html` | static | actor simulator |

## The harness (`harness/`)

Requires **Java 17+** for Karate / the IG Publisher (`.sdkmanrc` pins `21.0.5-tem`; run `sdk env`).

- **Batch battery** — `harness/run-tests.sh`: pulls fixtures from the `et.fhir.core.test` package
  and validates each against its profile (`good` passes, `bad` fails). Data-free; fixtures live in
  the [`et.fhir.core.test`](https://pmanko.github.io/et.fhir.core.test/) IG.
- **Interceptor** — `harness/interceptor/` (Dockerfile + `et-interceptor.feature` + `profileFor.json`).
  Profile selection: a resource's `meta.profile` wins, else the `profileFor` default, else base FHIR.
- **Actor simulator** — `harness/simulator/simulator.html` (served at `/sim`): config-driven actors
  (medication dispenser, …) that POST a payload (e.g. a `Patient+Encounter+MedicationDispense`
  bundle, conformant + broken) to `/intercept` and render the verdict.
- **Session** — `harness/test-session.sh`:
  ```bash
  cd harness
  ./test-session.sh          # fresh session; live ✓/✗ feed; Ctrl+C -> audit + HTML dashboard
  ./test-session.sh report   # rebuild the dashboard + audit from the current session
  ```
  The interceptor writes verdicts + seen patients to `harness/target/sessions/`; on exit the script
  audits what got stored and opens a session dashboard under `harness/target/runs/`.
- **Auditor** — `harness/features/auditor.feature`: finds everything stored for a patient and
  re-validates each resource via instance-level `$validate` (against its declared `meta.profile`).

## Postman
Import `docs/postman/ET-FHIR-Showcase.postman_collection.json` (set `host`, default
`https://localhost`): `$validate` (good/bad/bundle), POST with vs without `meta.profile` validation,
and the `/intercept` proxy.

## Related repos
- [`ETBase`](https://moh-ethiopia.github.io/ETBase/) — `et.fhir.core`, the Ethiopia Base IG (profiles).
- [`et.fhir.core.test`](https://github.com/pmanko/et.fhir.core.test) — paired test-fixture IG (CI + Pages).
- `fhir-zw-lab-test-ig` — the Zimbabwe reference this harness was adapted from.

## Notes
- H2 is for the sandbox only; the commented Postgres block in `config/application.yaml` is the
  upgrade path.
- Build artifacts (`igs/*.tgz`, `harness/target/`, `harness/karate-*.jar`, `.env`) are gitignored.
