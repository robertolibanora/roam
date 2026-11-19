#!/bin/bash
# Avvia Roam: backend e build/installazione dell'app.
#
# Uso: ./start.sh              backend + build e installazione sull'iPhone
#      ./start.sh --sim        backend + build e avvio sul simulatore
#      ./start.sh --no-ios     solo backend
#      ./start.sh --ios-only   solo build e installazione (backend lasciato com'è)
#      ./start.sh --test       esegue anche i test del backend prima di avviarlo
#      ./start.sh --stop       ferma il backend
# Le opzioni si combinano, es. ./start.sh --test --sim
# Variabili: ROAM_HOST (default 0.0.0.0: rete locale e Tailscale), ROAM_PORT (8000),
#            ROAM_START_TIMEOUT (120 s), ROAM_DEVICE e ROAM_SIMULATOR (vedi ios/install.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST="${ROAM_HOST:-0.0.0.0}"
CHECK_HOST="$HOST"; [ "$HOST" = 0.0.0.0 ] && CHECK_HOST=127.0.0.1
PORT="${ROAM_PORT:-8000}"
LOG="$ROOT/backend/server.log"
START_TIMEOUT="${ROAM_START_TIMEOUT:-120}"

BACKEND=true; IOS=device; TESTS=false; STOP=false
for arg in "$@"; do
  case "$arg" in
    --sim) IOS=sim ;;
    --no-ios) IOS=none ;;
    --ios-only) BACKEND=false ;;
    --test) TESTS=true ;;
    --stop) STOP=true ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✗ Opzione sconosciuta: $arg (vedi ./start.sh --help)" >&2; exit 1 ;;
  esac
done
if ! [[ "$START_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "✗ ROAM_START_TIMEOUT deve essere un numero intero positivo." >&2; exit 1
fi

stop_backend() {
  if PIDS=$(lsof -tiTCP:"$PORT" -sTCP:LISTEN); then
    echo "→ Fermo il backend ($PIDS)…"
    kill $PIDS
    for _ in {1..20}; do lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null || break; sleep 0.25; done
  fi
}
if [ "$STOP" = true ]; then stop_backend; echo "✓ Backend fermo"; exit 0; fi

# iCloud ("Ottimizza spazio") toglie dal Mac il contenuto dei file della Scrivania:
# riscaricarli prima evita avvii e build bloccati per minuti.
# I backup del database (roam.db.bak-*) non servono all'avvio e vengono saltati.
if ls -lOR "$ROOT/backend" "$ROOT/ios/Roam" 2>/dev/null | grep dataless | grep -qv '\.bak'; then
  echo "→ Scarico da iCloud i file del progetto…"
  find "$ROOT/backend" "$ROOT/ios" -type f -not -path '*/build/*' -not -path '*/__pycache__/*' -not -name '*.bak*' -print0 | xargs -0 cat >/dev/null
fi

if [ "$BACKEND" = true ]; then
  cd "$ROOT/backend"
  if [ ! -x .venv/bin/python ]; then
    echo "→ Creo l'ambiente Python…"
    python3 -m venv .venv
    .venv/bin/pip install -q -r requirements.txt
  fi
  if [ "$TESTS" = true ]; then
    echo "→ Test del backend…"
    if ! .venv/bin/python -m pytest -q -p no:cacheprovider >/tmp/roam-pytest.log 2>&1; then
      echo "✗ Test non superati, backend non riavviato:" >&2
      tail -30 /tmp/roam-pytest.log >&2
      exit 1
    fi
    tail -1 /tmp/roam-pytest.log
  fi
  stop_backend  # riparte sempre con il codice aggiornato
  echo "→ Avvio il backend su http://$HOST:$PORT (log: backend/server.log)…"
  # Il runtime standard evita il caricamento dei componenti nativi opzionali.
  nohup .venv/bin/python -u -c '
print("Caricamento del server…", flush=True)
import sys, uvicorn
uvicorn.run("main:app", host=sys.argv[1], port=int(sys.argv[2]), loop="asyncio", http="h11", ws="none", access_log=False)
' "$HOST" "$PORT" >"$LOG" 2>&1 </dev/null &
  BACKEND_PID=$!
  DEADLINE=$((SECONDS + START_TIMEOUT)); NEXT_NOTICE=$((SECONDS + 10)); READY=false
  while (( SECONDS < DEADLINE )); do
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
      wait "$BACKEND_PID" || true
      echo "✗ Il processo del backend si è interrotto. Dettagli:" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    # Il controllo locale ignora i proxy HTTP configurati sul Mac.
    if curl --noproxy '*' -fsS --connect-timeout 1 --max-time 1 "http://$CHECK_HOST:$PORT/health" >/dev/null 2>&1; then READY=true; break; fi
    if (( SECONDS >= NEXT_NOTICE )); then echo "→ Backend ancora in avvio…"; NEXT_NOTICE=$((SECONDS + 10)); fi
    sleep 0.5
  done
  if [ "$READY" != true ]; then
    echo "✗ Avvio non completato entro ${START_TIMEOUT}s (PID $BACKEND_PID). Ultime righe del log:" >&2
    tail -30 "$LOG" >&2; kill "$BACKEND_PID" 2>/dev/null || true; exit 1
  fi
  echo "✓ Backend attivo (PID $BACKEND_PID)"
fi

if [ "$IOS" != none ]; then
  INSTALL_LOG="$ROOT/ios/install.log"
  if [ "$IOS" = sim ]; then echo "→ Build e avvio sul simulatore…"; ARGS=(--sim); else echo "→ Build e installazione sull'iPhone…"; ARGS=(); fi
  if "$ROOT/ios/install.sh" ${ARGS[@]+"${ARGS[@]}"} >"$INSTALL_LOG" 2>&1; then
    echo "✓ App installata e avviata"
  elif grep -q "App installed" "$INSTALL_LOG"; then
    echo "⚠ App installata ma non avviata: sblocca l'iPhone e aprila a mano."
  elif grep -q "BUILD SUCCEEDED" "$INSTALL_LOG"; then
    echo "✗ Build riuscita ma iPhone non raggiungibile: collegalo, sbloccalo e rilancia ./start.sh --ios-only" >&2
    grep -E "^ERROR|CoreDeviceError" "$INSTALL_LOG" | head -3 >&2 || true
    exit 1
  else
    echo "✗ Build non riuscita (log: ios/install.log):" >&2
    # Solo le righe di diagnostica vere, non il codice sorgente citato nei warning.
    grep -E "^/.*: error: |^error: |BUILD FAILED" "$INSTALL_LOG" | head -20 >&2 || tail -20 "$INSTALL_LOG" >&2
    exit 1
  fi
fi
