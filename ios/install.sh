#!/bin/bash
# Compila Roam e la installa sull'iPhone associato (o sul simulatore con --sim).
# Uso: ios/install.sh          iPhone (ROAM_DEVICE per sceglierne un altro)
#      ios/install.sh --sim    simulatore (ROAM_SIMULATOR, default "iPhone 17 Pro")
# Sign in with Apple richiede un team a pagamento: ROAM_APPLE_SIGNIN=1 ios/install.sh
#
# La build parte da una copia in /tmp: sulla Scrivania (sincronizzata con iCloud)
# actool non riesce a leggere gli asset ("Operation not permitted").
set -euo pipefail
IOS="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROAM_BUILD_SRC:-/tmp/roam-src-ios}"
DEVICE="${ROAM_DEVICE:-2EA5531C-5005-58E3-B569-E710755E6851}"
SIMULATOR="${ROAM_SIMULATOR:-iPhone 17 Pro}"
BUNDLE=it.robertolibanora.roam
TARGET=device
[ "${1:-}" = "--sim" ] && TARGET=sim

rsync -a --delete --exclude build --exclude install.log "$IOS/" "$SRC/"
cd "$SRC"

if [ "$TARGET" = sim ]; then
  xcodebuild -project Roam.xcodeproj -scheme Roam -destination 'generic/platform=iOS Simulator' -configuration Debug \
    -derivedDataPath /tmp/roam-build CODE_SIGNING_ALLOWED=NO build
  xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
  # Le versioni recenti di Xcode mostrano il simulatore in DeviceHub; le precedenti in Simulator.
  XCODE_APPS="$(xcode-select -p)/../Applications"
  open "$XCODE_APPS/DeviceHub.app" 2>/dev/null || open "$(xcode-select -p)/Applications/Simulator.app" 2>/dev/null || true
  xcrun simctl install "$SIMULATOR" /tmp/roam-build/Build/Products/Debug-iphonesimulator/Roam.app
  xcrun simctl launch "$SIMULATOR" "$BUNDLE"
  exit 0
fi

# Indirizzi del Mac inseriti nell'app: a ogni avvio l'app usa il primo che risponde.
# Il nome Bonjour (.local) resta valido anche quando l'IP della rete locale cambia.
PORT="${ROAM_PORT:-8000}"
CANDIDATES="http://$(scutil --get LocalHostName).local:$PORT"
for IF in en0 en1; do IP=$(ipconfig getifaddr "$IF" 2>/dev/null || true); [ -n "$IP" ] && CANDIDATES+=",http://$IP:$PORT"; done
CANDIDATES+=",http://${ROAM_TAILSCALE_IP:-100.90.158.14}:$PORT"
echo "→ Indirizzi del backend: $CANDIDATES"

EXTRA=(ROAM_BACKEND_CANDIDATES="$CANDIDATES")
if [ "${ROAM_APPLE_SIGNIN:-0}" = "1" ]; then EXTRA+=(CODE_SIGN_ENTITLEMENTS=Roam/Roam.entitlements); fi
# Destinazione = iPhone specifico: così Xcode registra i dispositivi nuovi nel profilo di provisioning.
xcodebuild -project Roam.xcodeproj -scheme Roam -destination "id=$DEVICE" -configuration Debug \
  -derivedDataPath /tmp/roam-install DEVELOPMENT_TEAM=8A54VYSXGR PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration ${EXTRA[@]+"${EXTRA[@]}"} build
xcrun devicectl device install app --device "$DEVICE" /tmp/roam-install/Build/Products/Debug-iphoneos/Roam.app
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE"
