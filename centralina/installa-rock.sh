#!/bin/bash
# Installa la centralina luci su ROCK 4C+ (o qualsiasi Linux arm64/x64 con systemd).
# Uso:  curl -fsSL https://raw.githubusercontent.com/steoprimerano-lgtm/steo/main/centralina/installa-rock.sh | sudo bash
set -e

NODE_VER="v20.18.1"
DEST="/opt/centralina"
IP_NODO="${IP_NODO:-2.0.0.2/8}"

if [ "$(id -u)" != "0" ]; then echo "Lancia lo script con sudo."; exit 1; fi

echo "== 1/5 Controllo sistema"
case "$(uname -m)" in
  aarch64) NARCH="arm64" ;;
  x86_64)  NARCH="x64" ;;
  armv7l)  NARCH="armv7l" ;;
  *) echo "Architettura non supportata: $(uname -m)"; exit 1 ;;
esac
command -v curl >/dev/null || { echo "Manca curl"; exit 1; }

echo "== 2/5 Installo Node.js $NODE_VER"
if ! /usr/local/bin/node -v 2>/dev/null | grep -q "^v20"; then
  TMP=$(mktemp -d)
  curl -fsSL "https://nodejs.org/dist/$NODE_VER/node-$NODE_VER-linux-$NARCH.tar.gz" -o "$TMP/node.tgz"
  rm -rf /opt/node && mkdir -p /opt/node
  tar -xzf "$TMP/node.tgz" -C /opt/node --strip-components=1
  ln -sf /opt/node/bin/node /usr/local/bin/node
  rm -rf "$TMP"
fi
echo "   Node: $(/usr/local/bin/node -v)"

echo "== 3/5 Scarico il programma della centralina"
TMP=$(mktemp -d)
curl -fsSL "https://codeload.github.com/steoprimerano-lgtm/steo/tar.gz/refs/heads/main" -o "$TMP/app.tgz"
tar -xzf "$TMP/app.tgz" -C "$TMP"
SRC=$(find "$TMP" -maxdepth 1 -type d -name "steo-*" | head -1)
mkdir -p "$DEST/centralina" "$DEST/web"
cp -f "$SRC/centralina/server.js" "$SRC/centralina/libreria.js" "$DEST/centralina/"
cp -f "$SRC/web/index.html" "$DEST/web/"
rm -rf "$TMP"
echo "   File in $DEST (i dati salvati, dati-luci.json, restano)"

echo "== 4/5 Indirizzo fisso per la rete del nodo ($IP_NODO)"
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|end|enp)' | head -1)
[ -z "$IFACE" ] && IFACE="eth0"
echo "   Scheda di rete: $IFACE"
cat > /etc/systemd/system/centralina-ip.service <<EOF
[Unit]
Description=Indirizzo 2.x per il nodo Art-Net
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'for i in \$(seq 1 30); do ip link show $IFACE >/dev/null 2>&1 && break; sleep 1; done; ip addr add $IP_NODO dev $IFACE 2>/dev/null || true'
[Install]
WantedBy=multi-user.target
EOF

echo "== 5/5 Avvio automatico"
cat > /etc/systemd/system/centralina.service <<EOF
[Unit]
Description=Centralina luci
After=network.target centralina-ip.service
Wants=centralina-ip.service
[Service]
Environment=PORT=80
WorkingDirectory=$DEST/centralina
ExecStart=/usr/local/bin/node $DEST/centralina/server.js
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now centralina-ip.service >/dev/null 2>&1
systemctl enable centralina.service >/dev/null 2>&1
systemctl restart centralina.service
sleep 3

if systemctl is-active --quiet centralina.service; then
  echo ""
  echo "==================================================="
  echo " FATTO! La centralina parte da sola a ogni accensione."
  echo " Dal browser apri:"
  for a in $(hostname -I); do echo "   http://$a"; done
  echo "==================================================="
else
  echo "Qualcosa non va. Ultime righe del registro:"
  journalctl -u centralina.service -n 20 --no-pager
fi
