// Libreria profili DMX per la centralina: scarica dalla libreria di QLC+ (oltre 1.700 fari)
// e la converte nel formato dell'app. Il codice di conversione è lo stesso dell'app (index.html).
"use strict";
const https = require("https");
const fs = require("fs");
const path = require("path");

const CACHE = path.join(__dirname, "cache-libreria");
const htmlPath = fs.existsSync(path.join(__dirname, "index.html")) ? path.join(__dirname, "index.html") : path.join(__dirname, "..", "web", "index.html");
const html = fs.readFileSync(htmlPath, "utf8");
const a = html.indexOf("/*LIB-START*/"), b = html.indexOf("/*LIB-END*/");
if (a < 0 || b < 0) throw new Error("index.html non valido (marcatori LIB mancanti)");
const LIB = new Function(html.slice(a, b) + "\nreturn LIB;")();

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { "User-Agent": "centralina-luci" }, timeout: 15000 }, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) { res.resume(); return get(res.headers.location).then(resolve, reject); }
      if (res.statusCode !== 200) { res.resume(); return reject(new Error("HTTP " + res.statusCode)); }
      const chunks = []; res.on("data", c => chunks.push(c)); res.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    }).on("error", reject).on("timeout", function () { this.destroy(new Error("timeout")); });
  });
}
async function cached(name, url, maxAgeDays) {
  const file = path.join(CACHE, name.replace(/[^a-zA-Z0-9._-]/g, "_"));
  try { const st = fs.statSync(file); if (Date.now() - st.mtimeMs < maxAgeDays * 864e5) return fs.readFileSync(file, "utf8"); } catch (e) {}
  try {
    const txt = await get(url);
    fs.mkdirSync(CACHE, { recursive: true }); fs.writeFileSync(file, txt);
    return txt;
  } catch (e) {
    try { return fs.readFileSync(file, "utf8"); } catch (e2) {}
    throw new Error("Libreria non raggiungibile: la centralina deve essere collegata a internet (" + e.message + ")");
  }
}

let index = null;
async function search(q) {
  if (!index) index = LIB.parseIndex(await cached("FixturesMap.xml", LIB.BASE + "FixturesMap.xml", 30));
  return LIB.search(index, q);
}
async function getFixture(man, file) {
  if (!/^[^/\\]+$/.test(man) || !/^[^/\\]+$/.test(file)) throw new Error("nome non valido");
  return LIB.parseQxf(await cached(man + "__" + file + ".qxf", LIB.url(man, file), 365));
}
module.exports = { search, getFixture, parseQxf: LIB.parseQxf };
