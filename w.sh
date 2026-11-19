#!/bin/bash
# Avvia il backend e reinstalla Roam su tutti gli iPhone associati e raggiungibili
# (via cavo o sulla stessa rete Wi-Fi), così si collegano a questo backend.
#
# Uso: ./w.sh              backend + installazione su tutti gli iPhone
#      ./w.sh --ios-only   solo installazione (backend lasciato com'è)
# Un iPhone nuovo va prima associato una volta col cavo e con la Modalità sviluppatore attiva.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LOGDIR="$ROOT/ios/install-logs"
mkdir -p "$LOGDIR"

if [ "${1:-}" != "--ios-only" ]; then
  "$ROOT/start.sh" --no-ios || exit 1
fi

echo "→ Cerco gli iPhone associati…"
JSON="$(mktemp)"
xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1
# Riga per dispositivo: UDID<TAB>nome<TAB>modalità sviluppatore
DEVICES="$(python3 - "$JSON" <<'EOF'
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    h, c, p = d["hardwareProperties"], d["connectionProperties"], d["deviceProperties"]
    if h.get("reality") == "physical" and h.get("platform") == "iOS" and c.get("pairingState") == "paired":
        print(f'{h["udid"]}\t{p.get("name", "iPhone")}\t{p.get("developerModeStatus", "")}')
EOF
)"
rm -f "$JSON"
if [ -z "$DEVICES" ]; then echo "✗ Nessun iPhone associato." >&2; exit 1; fi

OK=(); FAILED=()
while IFS=$'\t' read -r UDID NAME DEVMODE; do
  if [ "$DEVMODE" = "disabled" ]; then
    echo "⚠ $NAME: Modalità sviluppatore disattivata, salto (Impostazioni → Privacy e sicurezza)."
    FAILED+=("$NAME (Modalità sviluppatore)"); continue
  fi
  LOG="$LOGDIR/${NAME//[^A-Za-z0-9]/_}.log"
  echo "→ $NAME: build e installazione (log: ${LOG#$ROOT/})…"
  if ROAM_DEVICE="$UDID" "$ROOT/ios/install.sh" >"$LOG" 2>&1; then
    echo "✓ $NAME: installata e avviata"; OK+=("$NAME")
  elif grep -q "App installed" "$LOG"; then
    echo "⚠ $NAME: installata ma non avviata (iPhone bloccato?)"; OK+=("$NAME")
  else
    echo "✗ $NAME: non riuscita — $(grep -E '^ERROR|error:' "$LOG" | head -1)"
    FAILED+=("$NAME")
  fi
done <<< "$DEVICES"

echo
LIST="$(IFS=,; echo "${OK[*]:-}")"
echo "Installata su ${#OK[@]} iPhone${LIST:+: ${LIST//,/, }}"
if [ ${#FAILED[@]} -gt 0 ]; then
  printf 'Non riuscita su: %s\n' "${FAILED[@]}"
  echo "Controlla che siano sbloccati e sulla stessa rete del Mac (o collegati col cavo)."
  exit 1
fi
