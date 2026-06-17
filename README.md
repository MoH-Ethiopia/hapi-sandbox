# Ethiopia FHIR Validation Sandbox

A sandbox for validating FHIR resources against the **official Ethiopia FHIR specifications** —
the Ethiopia Base IG ([`et.fhir.core`](https://moh-ethiopia.github.io/ETBase/)). Submit a resource
or bundle and get a conformance verdict against the published Ethiopian profiles.

It runs a FHIR server (the validation engine, with the Ethiopia IG loaded), a gateway that is the
single entrypoint, an always-on conformance **interceptor**, and a small test harness.

## Quick start

```bash
cp .env.example .env          # defaults to DOMAIN=localhost
docker compose up -d
open http://localhost:8095/docs/
```

The **gateway** is the one HTTP entrypoint (`127.0.0.1:8095`), routing `/fhir`, `/intercept`,
`/docs`, `/sim`. In production you front it with the host's TLS-terminating reverse proxy
(see [Deploy](#deploy)); locally you hit it directly. `docker compose ps` should show all services
healthy; it validates against the published Ethiopia IG by default.

## Three ways to validate

1. **Interceptor** — `POST http://localhost:8095/intercept` with a resource or transaction bundle.
   It validates against the Ethiopia profiles, returns the verdict in the `X-ET-Validation` header,
   and forwards to the server. Try it from the browser: `http://localhost:8095/sim/simulator.html`.
2. **`$validate`** — `POST http://localhost:8095/fhir/{Type}/$validate?profile=…` (or
   `/fhir/Bundle/$validate`) for a raw OperationOutcome — HAPI's standard operation.
   Ready-made requests are in `docs/postman/ET-FHIR-Showcase.postman_collection.json`.
3. **Batch** — `cd harness && ./run-tests.sh` validates a set of fixtures (valid must pass, invalid
   must fail).

Which Ethiopian profile a resource is checked against is taken from its own `meta.profile`.

## Routes
| Path | Purpose |
|---|---|
| `/fhir/*` | FHIR API (CRUD, search, `/metadata`) incl. `$validate`: `/fhir/{Type}/$validate`, `/fhir/Bundle/$validate` |
| `/intercept` | conformance proxy (validate → verdict headers → forward) |
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
- `DOMAIN` / `PUBLIC_BASE_URL` — the public name and HAPI's advertised base URL.
- `GATEWAY_PORT` — host port for the gateway (default `8095`); the fronting proxy forwards here.
- `ET_IG_PACKAGE_URL` etc. — the Ethiopia IGs. Default to the published Pages builds; point at a
  `file:///igs/*.tgz` (built by `harness/scripts/refresh-core-ig.sh`) for offline use.

## Deploy

The sandbox doesn't manage TLS — the host's reverse proxy does. Run the containers and forward to
the gateway (a single upstream that owns all routing).

1. Clone the repo, `cp .env.prod.example .env` (sets `DOMAIN=sandbox.fhir.et`, `GATEWAY_PORT=8095`;
   IGs stay on the published Pages builds, so no build/publisher on the server).
2. `docker compose up -d` — the gateway listens on `127.0.0.1:8095` (never `80`/`443`, so no clash
   with the host proxy).
3. Point the host proxy at it. With nginx: `proxy_pass http://127.0.0.1:8095;` under your
   `server_name` (TLS via Certbot). A ready block is in `deploy/nginx/sandbox.fhir.et.conf`:
   ```bash
   sudo cp deploy/nginx/sandbox.fhir.et.conf /etc/nginx/sites-available/sandbox.fhir.et
   sudo ln -sf /etc/nginx/sites-available/sandbox.fhir.et /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   sudo certbot --nginx -d sandbox.fhir.et   # once
   ```

Verify: `curl -sI https://sandbox.fhir.et/fhir/metadata` and open `https://sandbox.fhir.et/docs/`.

> The published Ethiopia IGs keep fixed versions while they iterate, so to pick up a new build force
> a reload: `docker compose down && rm -rf data && docker compose up -d`.

## Using it
See the **[tutorial](docs/tutorial.html)** (served at `/docs/tutorial.html`) for validating
resources/bundles, the interceptor, Postman, and running a conformance session.

## Related
- [`ETBase`](https://moh-ethiopia.github.io/ETBase/) — the official Ethiopia Base IG (`et.fhir.core`).
- [`et.fhir.core.test`](https://github.com/pmanko/et.fhir.core.test) — conformance test fixtures.
