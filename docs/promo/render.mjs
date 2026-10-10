// Frame-accurate offline render of reel.html.
// Drives Chrome over CDP, seeks the CSS animations to an exact time per frame,
// screenshots it, and pipes the JPEG straight into ffmpeg. No screen capture, no jitter.

import { spawn } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const FFMPEG = process.env.FFMPEG_BIN
  || path.join(process.env.LOCALAPPDATA, 'ms-playwright', 'ffmpeg-1011', 'ffmpeg-win64.exe');
const REEL = 'file:///C:/Windows_Applications/barangay_events/docs/promo/reel.html';

const FPS = Number(process.env.FPS || 30);
const DURATION = Number(process.env.DURATION || 90);
const OUT = process.argv[2] || 'reel.webm';
const TOTAL = Math.round(FPS * DURATION);

const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'reelchrome-'));

const chrome = spawn(CHROME, [
  '--headless=new',
  '--remote-debugging-port=9222',
  `--user-data-dir=${profileDir}`,
  '--window-size=1920,1080',
  '--hide-scrollbars',
  '--force-device-scale-factor=1',
  '--disable-gpu',
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-extensions',
  'about:blank',
], { stdio: 'ignore' });

async function cdpTarget() {
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch('http://127.0.0.1:9222/json/list');
      const list = await res.json();
      const page = list.find((t) => t.type === 'page' && t.webSocketDebuggerUrl);
      if (page) return page.webSocketDebuggerUrl;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('Chrome debug endpoint never came up');
}

const wsUrl = await cdpTarget();
const ws = new WebSocket(wsUrl);
await once(ws, 'open');

let msgId = 0;
const pending = new Map();
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
  }
});

const send = (method, params = {}) => {
  const id = ++msgId;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
};

const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  return r.result?.value;
};

await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false,
});

await send('Page.navigate', { url: REEL });
// wait for load, webfonts, and the app screenshots to decode
for (let i = 0; i < 120; i++) {
  const ready = await evaluate(`(async () => {
    if (document.readyState !== 'complete') return false;
    await document.fonts.ready;
    const imgs = [...document.images];
    return imgs.every(im => im.complete);
  })()`);
  if (ready) break;
  await new Promise((r) => setTimeout(r, 250));
}
const imgCount = await evaluate('document.images.length');
const imgOk = await evaluate('[...document.images].filter(i => i.naturalWidth > 0).length');
console.log(`page ready — ${imgOk}/${imgCount} images decoded`);

const isMp4 = OUT.toLowerCase().endsWith('.mp4');
const encodeArgs = isMp4
  ? ['-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-pix_fmt', 'yuv420p',
     '-g', '60', '-movflags', '+faststart']
  : ['-c:v', 'libvpx', '-b:v', '8M', '-pix_fmt', 'yuv420p',
     '-deadline', 'good', '-cpu-used', '2', '-auto-alt-ref', '0'];

const ffmpeg = spawn(FFMPEG, [
  '-hide_banner', '-y',
  '-f', 'image2pipe',
  '-c:v', 'mjpeg',            // the playwright build cannot probe a piped stream; name it explicitly
  '-framerate', String(FPS),
  '-i', 'pipe:0',
  ...encodeArgs,
  OUT,
], { stdio: ['pipe', 'ignore', 'pipe'] });

let ffErr = '';
let ffDead = false;
ffmpeg.stderr.on('data', (d) => { ffErr += d.toString(); if (ffErr.length > 8000) ffErr = ffErr.slice(-4000); });
ffmpeg.on('close', (c) => { if (c !== 0) ffDead = true; });
ffmpeg.stdin.on('error', () => { ffDead = true; });

const ffClosed = once(ffmpeg, 'close');   // one listener, reused for backpressure races
const t0 = Date.now();
for (let f = 0; f < TOTAL; f++) {
  const t = (f / FPS) * 1000;
  await evaluate(`(() => {
    for (const a of document.getAnimations()) { try { a.currentTime = ${t}; a.pause(); } catch (e) {} }
    return true;
  })()`);
  const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 92, captureBeyondViewport: false });
  if (ffDead) {
    console.log('ffmpeg died early:\n' + ffErr.slice(-1500));
    break;
  }
  const buf = Buffer.from(shot.data, 'base64');
  if (!ffmpeg.stdin.write(buf)) {
    await Promise.race([once(ffmpeg.stdin, 'drain'), ffClosed]);
  }
  if (f % 150 === 0 || f === TOTAL - 1) {
    const pct = (((f + 1) / TOTAL) * 100).toFixed(1);
    const el = ((Date.now() - t0) / 1000).toFixed(0);
    console.log(`frame ${f + 1}/${TOTAL}  ${pct}%  ${el}s elapsed`);
  }
}

ffmpeg.stdin.end();
const [code] = await once(ffmpeg, 'close');
console.log(`ffmpeg exit ${code}`);
if (code !== 0) console.log(ffErr.slice(-2000));

ws.close();
chrome.kill();
try { fs.rmSync(profileDir, { recursive: true, force: true }); } catch {}
console.log('done:', OUT);
