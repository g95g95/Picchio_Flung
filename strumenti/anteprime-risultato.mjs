// Genera anteprime/<km>.jpg (1200x630), l'anteprima del link condiviso con ?km=<km>, per km = 0, 5, ... 500.
// Comando, dalla radice del repo: node strumenti/anteprime-risultato.mjs
// Serve Node 24, Python ed Edge. Variabili facoltative: PYTHON, EDGE.
// Lo script avvia server.py su una porta libera, apre il gioco in Edge headless e disegna l'immagine
// dentro la pagina con journeySVG, journeySet e stopFor del gioco. Alla fine ferma Edge e il server.
import {spawn, spawnSync} from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'anteprime');
const PYTHON = process.env.PYTHON || 'python';
const EDGE = process.env.EDGE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const QUALITA = 80, MAX_BYTE = 100 * 1024;
const sleep = ms => new Promise(r => setTimeout(r, ms));

const CSS = `
#anteprima{position:fixed;left:0;top:0;width:1200px;height:630px;z-index:2147483647;overflow:hidden;color:#2a1f17;
  background:#f4ead0;background-image:radial-gradient(rgba(90,70,40,.06) 1px,transparent 1.2px);background-size:7px 7px}
#anteprima .percorso{position:absolute;left:14px;top:14px;width:368px;height:602px;border-right:3px solid #2a1f17}
#anteprima .percorso svg{display:block;width:365px;height:602px}
#anteprima .percorso text{font-weight:700}
#anteprima .testo{position:absolute;left:382px;right:14px;top:14px;bottom:14px;display:flex;flex-direction:column;align-items:center;justify-content:center}
#anteprima h1{font-family:'Bowlby One SC',serif;font-weight:400;font-size:88px;letter-spacing:.06em;line-height:1;text-shadow:5px 5px 0 #b8322a}
#anteprima .km{font-family:'Bowlby One SC',serif;color:#b8322a;line-height:1;margin:34px 0 26px;white-space:nowrap;text-shadow:6px 6px 0 #2a1f17}
#anteprima .km b{font-weight:400;font-size:220px}
#anteprima .km span{font-size:84px;margin-left:18px}
#anteprima h2{font-family:'Special Elite',monospace;font-weight:400;font-size:50px;display:flex;align-items:center;gap:22px;white-space:nowrap}
#anteprima h2:before,#anteprima h2:after{content:"";height:10px;width:44px;border-top:3px solid #b8322a;border-bottom:3px solid #b8322a}
#anteprima .cornice{position:absolute;inset:0;border:14px solid #2a1f17}`;

// Funzioni eseguite nella pagina del gioco (serializzate con toString).
async function prepara(css) {
  const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
  const box = document.createElement('div'); box.id = 'anteprima';
  box.innerHTML = '<div class="percorso"></div><div class="testo"><h1>LENTÀ</h1><div class="km"><b></b><span>km</span></div><h2></h2></div><div class="cornice"></div>';
  // Primo nel documento: journeySet cerca #jprog con getElementById.
  document.body.prepend(box);
  [...document.body.children].forEach(e => { if (e !== box) e.style.display = 'none'; });
  await Promise.all(['40px "Bowlby One SC"', '40px "Special Elite"', '40px "Courier Prime"', 'bold 40px "Courier Prime"'].map(f => document.fonts.load(f, 'LENTÀ 0123456789')));
  await document.fonts.ready;
}
function disegna(km) {
  const box = document.getElementById('anteprima');
  box.querySelector('.km b').textContent = km;
  box.querySelector('h2').textContent = stopFor(km).n;
  box.querySelector('.percorso').innerHTML = journeySVG();
  journeySet(km, false);
  // journeySet posiziona lo sprite in requestAnimationFrame e scrive data-v sul tracciato quando ha finito.
  return new Promise(fatto => { const giro = () => document.getElementById('jprog').dataset.v === undefined ? requestAnimationFrame(giro) : requestAnimationFrame(() => fatto()); giro(); });
}

function portaLibera() {
  return new Promise((ok, ko) => {
    const s = net.createServer().once('error', ko);
    s.listen(0, '127.0.0.1', () => { const {port} = s.address(); s.close(() => ok(port)); });
  });
}

async function attendi(cosa, prova, ms = 15000) {
  for (const fine = Date.now() + ms; Date.now() < fine; await sleep(100)) {
    try { const v = await prova(); if (v) return v; } catch {}
  }
  throw new Error(`Tempo scaduto: ${cosa}`);
}

// Ferma il processo e i suoi figli (Edge e il lanciatore di Python ne creano).
async function ferma(p) {
  if (!p || p.exitCode !== null || p.signalCode !== null) return;
  const uscito = new Promise(r => p.once('exit', r));
  if (process.platform === 'win32') spawnSync('taskkill', ['/pid', String(p.pid), '/T', '/F'], {stdio: 'ignore'});
  else p.kill();
  await Promise.race([uscito, sleep(5000)]);
}

let server, edge, ws;
const profilo = fs.mkdtempSync(path.join(os.tmpdir(), 'lenta-anteprime-'));
try {
  let porta; do porta = await portaLibera(); while (porta === 8795 || porta === 8791);
  server = spawn(PYTHON, ['-I', 'server.py'], {cwd: ROOT, stdio: 'ignore', env: {...process.env, PICCHIO_HOST: '127.0.0.1', PICCHIO_PORT: String(porta)}});
  const sito = `http://127.0.0.1:${porta}`;
  await attendi('server.py', async () => (await fetch(sito + '/healthz')).ok);

  edge = spawn(EDGE, ['--headless', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
    '--remote-debugging-port=0', '--user-data-dir=' + profilo, '--window-size=1200,630', 'about:blank'], {stdio: 'ignore'});
  const devtools = await attendi('Edge', () => fs.readFileSync(path.join(profilo, 'DevToolsActivePort'), 'utf8').split('\n')[0].trim());
  const pagina = await attendi('pagina di Edge', async () => (await (await fetch(`http://127.0.0.1:${devtools}/json`)).json()).find(t => t.type === 'page'));

  ws = new WebSocket(pagina.webSocketDebuggerUrl);
  await new Promise((ok, ko) => { ws.onopen = ok; ws.onerror = ko; });
  let id = 0; const attese = {}, errori = [];
  ws.onmessage = e => {
    const m = JSON.parse(e.data);
    if (attese[m.id]) { attese[m.id](m); delete attese[m.id]; }
    if (m.method === 'Runtime.exceptionThrown') errori.push(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text);
  };
  const cmd = (method, params = {}) => new Promise((ok, ko) => {
    attese[++id] = m => m.error ? ko(new Error(`${method}: ${m.error.message}`)) : ok(m.result);
    ws.send(JSON.stringify({id, method, params}));
  });
  const valuta = async x => {
    const r = await cmd('Runtime.evaluate', {expression: x, awaitPromise: true, returnByValue: true});
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  };

  await cmd('Runtime.enable'); await cmd('Page.enable');
  await cmd('Emulation.setDeviceMetricsOverride', {width: 1200, height: 630, deviceScaleFactor: 1, mobile: false});
  await cmd('Page.navigate', {url: sito + '/'});
  await attendi('caricamento del gioco', () => valuta("document.readyState==='complete'&&typeof journeySVG==='function'"));
  await valuta(`(${prepara})(${JSON.stringify(CSS)})`);

  fs.mkdirSync(OUT, {recursive: true});
  let totale = 0, massimo = 0;
  for (let km = 0; km <= 500; km += 5) {
    await valuta(`(${disegna})(${km})`);
    const shot = await cmd('Page.captureScreenshot', {format: 'jpeg', quality: QUALITA, clip: {x: 0, y: 0, width: 1200, height: 630, scale: 1}});
    const dati = Buffer.from(shot.data, 'base64');
    if (dati.length > MAX_BYTE) throw new Error(`anteprime/${km}.jpg: ${dati.length} byte, oltre ${MAX_BYTE}. Abbassa QUALITA.`);
    fs.writeFileSync(path.join(OUT, km + '.jpg'), dati);
    totale += dati.length; massimo = Math.max(massimo, dati.length);
  }
  if (errori.length) throw new Error('Errori nella pagina del gioco:\n' + errori.join('\n'));
  console.log(`101 immagini in anteprime/, qualità ${QUALITA}: media ${(totale / 101 / 1024).toFixed(1)} KB, massima ${(massimo / 1024).toFixed(1)} KB, totale ${(totale / 1024).toFixed(0)} KB.`);
} finally {
  if (ws?.readyState === WebSocket.OPEN) ws.close();
  await ferma(edge);
  await ferma(server);
  fs.rmSync(profilo, {recursive: true, force: true, maxRetries: 10, retryDelay: 200});
}
