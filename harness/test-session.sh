#!/usr/bin/env bash
# Conformance SESSION for the containerized interceptor.
#
#   ./test-session.sh           # live: fresh session, live feed; Ctrl+C -> audit + dashboard
#   ./test-session.sh report    # just (re)build the dashboard + audit from the current session
#
# Point your system / simulator at the interceptor (default http://localhost:8095/intercept),
# or open the simulator at http://localhost:8095/sim/simulator.html. Every POST is validated
# against the ET profiles on the way through; the interceptor records each verdict and the
# patients it saw. On exit this audits what got stored and opens an HTML session dashboard.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
CMD="${1:-live}"
LABEL="${LABEL:-session}"
INTERCEPT_URL="${INTERCEPT_URL:-http://localhost:8095/intercept}"
SHR_URL="${SHR_URL:-http://localhost:8090/fhir}"   # where the auditor checks stored data
KARATE_VERSION="${KARATE_VERSION:-2.0.3}"
JAR="karate-${KARATE_VERSION}.jar"
LIVE="target/sessions"                              # mounted into the interceptor at /sessions
mkdir -p "$LIVE" target/runs

ensure_jar() { [ -f "$JAR" ] || curl -fsL -o "$JAR" \
  "https://github.com/karatelabs/karate/releases/download/v${KARATE_VERSION}/karate-${KARATE_VERSION}.jar"; }

build_report() {
  local archive; archive="target/runs/$(date +%Y%m%d-%H%M%S)-${LABEL}"; mkdir -p "$archive"
  local reports="$LIVE/validation-reports.json" patients="$LIVE/patients.txt"
  [ -s "$reports" ] && cp "$reports" "$archive/validation-reports.json"
  [ -s "$patients" ] && cp "$patients" "$archive/patients.txt"

  if [ -s "$reports" ]; then
    local total pass; total=$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))))' "$reports" 2>/dev/null || echo 0)
    pass=$(python3 -c 'import json,sys;print(sum(1 for r in json.load(open(sys.argv[1])) if r.get("errors",0)==0))' "$reports" 2>/dev/null || echo 0)
    echo "session summary:  ✓ ${pass} conformant   ✗ $((total-pass)) with findings   (${total} requests)"
  else
    echo "⚠ no requests recorded — point your client/simulator at ${INTERCEPT_URL}"
  fi

  if [ -s "$patients" ]; then
    ensure_jar
    echo "── auditing stored data on ${SHR_URL} ──"
    while IFS= read -r ident || [ -n "$ident" ]; do
      [ -z "$ident" ] && continue
      echo "· auditing ${ident}"
      AUDIT_PATIENT_IDENTIFIER="$ident" java -Dshr="$SHR_URL" -jar "$JAR" features/auditor.feature >/dev/null 2>&1 \
        && echo "    ✓ stored data conforms" || echo "    ✗ findings (or patient not stored) — see report"
    done < "$patients"
    [ -d target/karate-reports ] && cp -R target/karate-reports "$archive/audit-report"
  fi

  python3 - "$reports" "$archive" "$LABEL" "$SHR_URL" <<'PY'
import json, sys, os, html
reports_path, archive, label, shr = sys.argv[1:5]
try: reports = json.load(open(reports_path))
except Exception: reports = []
rows = ""
for r in reports:
    errs = r.get("errors", 0); cls = "ok" if errs == 0 else "bad"
    res = "✓ conformant" if errs == 0 else f"✗ {errs} error(s)"
    issues = "".join(
        f'<div class="issue"><b>{html.escape(i.get("severity","error"))}</b> '
        f'<code>{html.escape(i.get("location","") or "(resource)")}</code>'
        f'<div class="msg">{html.escape(i.get("message",""))}</div></div>'
        for i in r.get("issues", []))
    rows += (f'<tr class="{cls} click"><td>{html.escape(r.get("id",""))}</td>'
             f'<td>{html.escape(r.get("action",""))}</td><td>{html.escape(str(r.get("subject","")))}</td>'
             f'<td class="result">{res}</td></tr>')
    if issues:
        rows += f'<tr class="detail" style="display:none"><td colspan=4>{issues}<div class=prof>vs {html.escape(str(r.get("profile","")))}</div></td></tr>'
audit_rel = "audit-report/karate-summary.html"
audit = f'<iframe src="{audit_rel}"></iframe>' if os.path.exists(os.path.join(archive, audit_rel)) else '<p class=note>no audit ran (no patients seen)</p>'
open(os.path.join(archive, "session.html"), "w").write(f"""<!doctype html><meta charset=utf-8><title>ET session — {html.escape(label)}</title>
<style>body{{font-family:-apple-system,Segoe UI,sans-serif;margin:1.4rem;background:#0e0f10;color:#e8e9ea}}
h1{{font-size:1.15rem;margin:.2rem 0}} h3{{font-size:.95rem;color:#cdd2d6}} .note{{color:#9aa0a6;font-size:.85rem}}
table{{border-collapse:collapse;width:100%;background:#17191b;border:1px solid #2a2d30;border-radius:8px;overflow:hidden}}
th,td{{padding:.5rem .8rem;border-bottom:1px solid #2a2d30;text-align:left;font-size:.88rem}}
th{{color:#9aa0a6;text-transform:uppercase;font-size:.72rem;letter-spacing:.04em}}
tr.ok .result{{color:#7ee29a;font-weight:600}} tr.bad .result{{color:#ff9b95;font-weight:600}} tr.click{{cursor:pointer}}
tr.detail td{{background:#0b0c0d}} .issue{{border-left:3px solid #e5534b;padding:.2rem .6rem;margin:.25rem 0}}
.issue b{{color:#ff9b95;text-transform:uppercase;font-size:.7rem;margin-right:.4rem}} .issue code{{color:#e3b341}}
.prof{{color:#9aa0a6;font-size:.75rem;margin-top:.3rem}} iframe{{width:100%;height:70vh;border:1px solid #2a2d30;background:#fff;margin-top:.6rem}}
.panes{{display:flex;gap:1.2rem;flex-wrap:wrap;align-items:flex-start}} .panes>div{{flex:1;min-width:420px}}</style>
<h1>ET conformance session — {html.escape(label)}</h1>
<div class=note>target: {html.escape(shr)} · {len(reports)} requests</div>
<div class=panes>
<div><h3>Live traffic — verdicts</h3>
<table><tr><th>id</th><th>action</th><th>subject</th><th>result</th></tr>
{rows or '<tr><td colspan=4 class=note>no requests recorded</td></tr>'}</table>
<p class=note>click a row with findings for issue details</p></div>
<div><h3>Stored-data audit</h3>{audit}</div></div>
<script>document.querySelectorAll('tr.click').forEach(t=>{{t.addEventListener('click',()=>{{const d=t.nextElementSibling;if(d&&d.classList.contains('detail'))d.style.display=d.style.display==='none'?'':'none';}});}});</script>
""")
print("dashboard:", os.path.join(archive, "session.html"))
PY
  command -v open >/dev/null 2>&1 && open "$archive/session.html" 2>/dev/null || true
}

if [ "$CMD" = "report" ]; then build_report; exit 0; fi

# ---- live session ----
rm -f "$LIVE/validation-reports.json" "$LIVE/patients.txt"
echo "starting a fresh interceptor session…"
( cd "$ROOT" && docker compose restart interceptor >/dev/null 2>&1 )
sleep 4
cat <<EOF
──────────────────────────────────────────────
 ET conformance session — ${LABEL}
 Point your system / simulator at:  ${INTERCEPT_URL}
   or open  http://localhost:8095/sim/simulator.html
 Stop with Ctrl+C for the audit + dashboard.
──────────────────────────────────────────────
live feed (one line per request):
EOF
cleanup() { trap - INT TERM; kill "${FEED_PID:-}" 2>/dev/null; echo; echo "── ending session ──"; build_report; exit 0; }
trap cleanup INT TERM
( cd "$ROOT" && docker compose logs -f --since 1s interceptor 2>/dev/null ) | while IFS= read -r line; do
  case "$line" in
    *ETPROXY\|push\|*\|0\ errors*) echo "  ✓ $(printf '%s' "$line" | sed -E 's/.*ETPROXY\|push\|([^|]*)\|.*/\1 — conformant/')" ;;
    *ETPROXY\|push\|*errors*)      echo "  ✗ $(printf '%s' "$line" | sed -E 's/.*ETPROXY\|push\|([^|]*)\|([0-9]+) errors.*/\1 — \2 error(s)/')" ;;
  esac
done &
FEED_PID=$!
wait "$FEED_PID"
