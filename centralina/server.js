// Centralina Luci – programma della centralina (Raspberry Pi o computer)
// Avvio:  node server.js        Poi apri  http://<indirizzo-centralina>:8080
// Non servono librerie esterne: basta Node.js 18 o più recente.
"use strict";
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");
const dgram = require("dgram");
const { exec } = require("child_process");

const PORT = Number(process.env.PORT) || 8080;
const DIR = __dirname;
const HTML_FILE = fs.existsSync(path.join(DIR, "index.html")) ? path.join(DIR, "index.html") : path.join(DIR, "..", "web", "index.html");
const DATA_FILE = path.join(DIR, "dati-luci.json");
const FPS = 40;

/* ---------- motore effetti: lo stesso codice dell'app ---------- */
const html = fs.readFileSync(HTML_FILE, "utf8");
const a = html.indexOf("/*ENGINE-START*/"), b = html.indexOf("/*ENGINE-END*/");
if (a < 0 || b < 0) { console.error("index.html non valido (marcatori ENGINE mancanti)"); process.exit(1); }
const engineCode = html.slice(a, b);
const engine = new Function("performance", "localStorage", engineCode + `
  return {
    apply(d){
      registerProfiles(d.profiles||[]); fixtures=d.fixtures; decor=d.decor; stage=d.stage; net=d.net; presets=d.presets||[];
      const def=defaultState(); S=Object.assign(def,d.state||{});
      S.par=Object.assign(defaultState().par,S.par); S.heads=Object.assign(defaultState().heads,S.heads); S.fog=Object.assign(defaultState().fog,S.fog);
    },
    defaults(){ return {fixtures:defaultFixtures(),decor:defaultDecor(),stage:{w:8,d:5},net:{ip:"2.255.255.255",uni:0},state:defaultState(),presets:[],profiles:[]}; },
    mom(m){ if("limPrev" in m) limPrev=(m.limPrev&&typeof m.limPrev.id==="string")?{id:m.limPrev.id,v:Math.max(0,Math.min(255,+m.limPrev.v||0))}:null; if("flash" in m) flash=!!m.flash; if("fogHold" in m) fogHold=!!m.fogHold; if("point" in m) point=!!m.point;
            if(m.fogFor) fogUntil=Math.max(fogUntil,performance.now()+Math.min(30000,+m.fogFor)); },
    tap(){ tStart=performance.now(); },
    frame(){ const t=(performance.now()-tStart)/1000; dmx.fill(0); computePars(t); computeHeads(t); computeFog(t); return dmx; },
    net(){ return net; }
  };`)(require("perf_hooks").performance, { getItem(){ return null; }, setItem(){} });

/* ---------- dati salvati ---------- */
let data = null;
try { data = JSON.parse(fs.readFileSync(DATA_FILE, "utf8")); console.log("Dati caricati da", DATA_FILE); }
catch (e) { console.log("Nessun dato salvato: li prendo dal primo dispositivo che si collega."); }
engine.apply(data || engine.defaults());
let saveTimer = null;
function saveData() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    const tmp = DATA_FILE + ".tmp";
    fs.writeFile(tmp, JSON.stringify(data, null, 1), err => { if (!err) fs.rename(tmp, DATA_FILE, () => {}); });
  }, 800);
}

/* ---------- Art-Net ---------- */
const udp = dgram.createSocket({ type: "udp4", reuseAddr: true });
udp.bind(() => { try { udp.setBroadcast(true); } catch (e) {} });
let seq = 0, lastErr = 0;
function artDmx(universe, dmx) {
  const p = Buffer.alloc(18 + 512);
  p.write("Art-Net\0", 0, "ascii");
  p.writeUInt16LE(0x5000, 8);      // OpDmx
  p.writeUInt16BE(14, 10);         // versione protocollo
  seq = (seq % 255) + 1; p[12] = seq; p[13] = 0;
  p[14] = universe & 0xff; p[15] = (universe >> 8) & 0x7f;
  p.writeUInt16BE(512, 16);
  Buffer.from(dmx.buffer, dmx.byteOffset, 512).copy(p, 18);
  return p;
}
setInterval(() => {
  const dmx = engine.frame();
  const n = engine.net() || {};
  const ip = n.ip || "2.255.255.255";
  udp.send(artDmx(n.uni | 0, dmx), 6454, ip, err => {
    if (err && Date.now() - lastErr > 10000) { lastErr = Date.now(); console.log("Art-Net: non riesco a inviare a", ip, "-", err.message); }
  });
}, 1000 / FPS);

/* ---------- pagina web ---------- */
const libreria = require("./libreria.js");
function sendJson(res, code, obj) { res.writeHead(code, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" }); res.end(JSON.stringify(obj)); }
const server = http.createServer((req, res) => {
  const u = new URL(req.url, "http://x");
  if (u.pathname === "/api/lib/search") {
    return libreria.search(u.searchParams.get("q") || "").then(r => sendJson(res, 200, { results: r }), e => sendJson(res, 502, { error: e.message }));
  }
  if (u.pathname === "/api/lib/get") {
    return libreria.getFixture(u.searchParams.get("man") || "", u.searchParams.get("file") || "").then(r => sendJson(res, 200, r), e => sendJson(res, 502, { error: e.message }));
  }
  if (req.url === "/" || req.url.startsWith("/?") || req.url === "/index.html") {
    fs.readFile(HTML_FILE, (err, buf) => {
      if (err) { res.writeHead(500); return res.end("index.html mancante"); }
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
      res.end(buf);
    });
  } else { res.writeHead(404); res.end(); }
});

/* ---------- WebSocket (minimo, senza librerie) ---------- */
const clients = new Set();
function wsSend(sock, obj) {
  const payload = Buffer.from(JSON.stringify(obj));
  const len = payload.length;
  let head;
  if (len < 126) head = Buffer.from([0x81, len]);
  else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x81; head[1] = 126; head.writeUInt16BE(len, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x81; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
  try { sock.write(Buffer.concat([head, payload])); } catch (e) {}
}
function info() { return { type: "info", host: os.hostname(), clients: clients.size, canShutdown: process.platform === "linux" }; }
function broadcastInfo() { for (const c of clients) wsSend(c, info()); }

function onMessage(sock, txt) {
  let m; try { m = JSON.parse(txt); } catch (e) { return; }
  if (m.type === "state" && m.data && Array.isArray(m.data.fixtures)) {
    data = m.data; engine.apply(data); saveData();
    for (const c of clients) if (c !== sock) wsSend(c, { type: "state", data });
  } else if (m.type === "mom") engine.mom(m);
  else if (m.type === "tap") engine.tap();
  else if (m.type === "shutdown" && process.platform === "linux") {
    console.log("Spegnimento richiesto dall'app");
    exec("sudo shutdown -h now", err => { if (err) console.log("Spegnimento non riuscito:", err.message); });
  }
}

server.on("upgrade", (req, sock) => {
  if (req.url !== "/ws" || !req.headers["sec-websocket-key"]) return sock.destroy();
  const accept = crypto.createHash("sha1").update(req.headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  sock.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n");
  sock.setNoDelay(true);
  clients.add(sock);
  let buf = Buffer.alloc(0), frag = [];
  sock.on("data", chunk => {
    buf = Buffer.concat([buf, chunk]);
    while (buf.length >= 2) {
      const fin = buf[0] & 0x80, op = buf[0] & 0x0f, masked = buf[1] & 0x80;
      let len = buf[1] & 0x7f, off = 2;
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
      const mOff = off; if (masked) off += 4;
      if (buf.length < off + len) return;
      let pl = buf.subarray(off, off + len);
      if (masked) { const k = buf.subarray(mOff, mOff + 4); pl = Buffer.from(pl); for (let i = 0; i < pl.length; i++) pl[i] ^= k[i & 3]; }
      buf = buf.subarray(off + len);
      if (op === 8) { sock.end(); return; }
      if (op === 9) { sock.write(Buffer.concat([Buffer.from([0x8a, pl.length]), pl])); continue; }
      if (op === 1 || op === 0) { frag.push(pl); if (fin) { const t = Buffer.concat(frag).toString("utf8"); frag = []; onMessage(sock, t); } }
    }
  });
  const bye = () => { if (clients.delete(sock)) broadcastInfo(); };
  sock.on("close", bye); sock.on("error", bye);
  if (data) wsSend(sock, { type: "state", data }); else wsSend(sock, { type: "need" });
  broadcastInfo();
});

server.listen(PORT, () => {
  console.log("\n=== Centralina Luci attiva ===");
  console.log("Apri l'app da questo computer:   http://localhost:" + PORT);
  const nets = os.networkInterfaces();
  for (const name in nets) for (const n of nets[name]) if (n.family === "IPv4" && !n.internal)
    console.log("Da iPad/telefono (" + name + "):   http://" + n.address + ":" + PORT);
  console.log("Oppure:                          http://" + os.hostname().replace(/\.local$/, "") + ".local:" + PORT);
  console.log("Art-Net verso: " + ((engine.net() || {}).ip) + "  (si cambia in Setup → Rete Art-Net)");
  console.log("Per fermare: Ctrl+C\n");
});
