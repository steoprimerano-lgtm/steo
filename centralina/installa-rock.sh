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
# toglie la vecchia versione (bloccava la rete al riavvio)
if [ -f /etc/systemd/system/centralina-ip.service ]; then
  systemctl disable centralina-ip.service >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/centralina-ip.service
fi
RELOAD_NET=""
if command -v nmcli >/dev/null && systemctl is-active --quiet NetworkManager; then
  # profilo "casa": DHCP + 2.0.0.2. Se non arriva l'indirizzo dal router (rete luci), NM passa al profilo "centralina-luci"
  CON=$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v d="$IFACE" '$2==d && $1!="centralina-luci"{print $1; exit}')
  [ -z "$CON" ] && CON=$(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-3-ethernet" && $1!="centralina-luci"{print $1; exit}')
  if [ -z "$CON" ]; then nmcli con add type ethernet ifname "$IFACE" con-name centralina >/dev/null; CON="centralina"; fi
  nmcli con mod "$CON" ipv4.method auto connection.autoconnect yes connection.autoconnect-priority 0 connection.autoconnect-retries -1 ipv4.dhcp-timeout 0
  nmcli con mod "$CON" -ipv4.addresses "$IP_NODO" >/dev/null 2>&1 || true
  nmcli con mod "$CON" +ipv4.addresses "$IP_NODO"
  # il router delle luci dà indirizzi automatici: basta un solo profilo (DHCP + 2.0.0.2)
  nmcli con delete centralina-luci >/dev/null 2>&1 || true
  echo "   Connessione \"$CON\": indirizzo automatico + $IP_NODO"
  RELOAD_NET=""
else
  # sistemi senza NetworkManager: alias in /etc/network/interfaces.d
  mkdir -p /etc/network/interfaces.d
  printf "auto %s\nallow-hotplug %s\niface %s inet dhcp\n    up ip addr add %s dev %s || true\n" "$IFACE" "$IFACE" "$IFACE" "$IP_NODO" "$IFACE" > /etc/network/interfaces.d/centralina
  ip link set "$IFACE" up; ip addr add "$IP_NODO" dev "$IFACE" 2>/dev/null || true
  echo "   Configurato in /etc/network/interfaces.d/centralina"
fi

echo "== 5/5 Avvio automatico"
cat > /etc/systemd/system/centralina.service <<EOF
[Unit]
Description=Centralina luci
After=network.target
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
systemctl enable centralina.service >/dev/null 2>&1
systemctl restart centralina.service
sleep 3

if systemctl is-active --quiet centralina.service; then
  echo ""
  echo "==================================================="
  echo " FATTO! La centralina parte da sola a ogni accensione."
  echo " Dal browser apri:"
  for a in $(hostname -I) 2.0.0.2; do echo "   http://$a"; done
  echo "==================================================="
  if [ -n "$RELOAD_NET" ]; then
    echo " Applico la rete: se la finestra si blocca, aspetta 10 secondi e ricollegati."
    (sleep 2; nmcli con up "$RELOAD_NET" >/dev/null 2>&1) &
  fi
else
  echo "Qualcosa non va. Ultime righe del registro:"
  journalctl -u centralina.service -n 20 --no-pager
fi
