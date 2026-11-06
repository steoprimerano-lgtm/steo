#!/bin/bash
# Doppio clic per avviare la Centralina Luci sul Mac
cd "$(dirname "$0")"
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js non è installato. Scaricalo da https://nodejs.org (versione LTS) e riprova."
  read -n 1 -s -r -p "Premi un tasto per chiudere"
  exit 1
fi
node server.js
