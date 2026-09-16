// node test/benchmarks/chrome_profile.mjs BEFORE_BUILD AFTER_BUILD CHECK_BUILD OUTPUT_DIR
// Uses a dedicated visible Chrome profile and local-only static server. No npm dependencies.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFile, writeFile, mkdir, mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join, extname, sep } from 'node:path';

const [before, after, check, output] = process.argv.slice(2).map(p => resolve(p));
if (!output) throw new Error('Provide before, after, check and output directories.');
await mkdir(output, { recursive: true });
const roots = { before, after, check };
const variants = process.env.PROFILE_VARIANT ? [process.env.PROFILE_VARIANT]
  : process.env.PROFILE_REVERSE ? ['after', 'before'] : ['before', 'after'];
if (variants.some(v => !['before', 'after'].includes(v))) throw new Error('Unknown profile variant');
const server = createServer(async (request, response) => {
  try {
    const parts = new URL(request.url, 'http://localhost').pathname.split('/');
    const root = roots[parts[1]];
    if (!root) throw new Error('Unknown build');
    const name = decodeURIComponent(parts.slice(2).join('/')) || 'index.html';
    const file = resolve(root, name);
    if (!file.startsWith(root + sep)) throw new Error('Outside build');
    const type = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
      '.json': 'application/json', '.png': 'image/png' }[extname(file)] || 'application/octet-stream';
    response.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
    const body = await readFile(file);
    response.end(extname(file) === '.html'
      ? body.toString().replace('<base href="/">', `<base href="/${parts[1]}/">`)
      : body);
  } catch { response.writeHead(404); response.end(); }
});
await new Promise(done => server.listen(0, '127.0.0.1', done));
const webPort = server.address().port;
const profile = await mkdtemp(join(tmpdir(), 'a-borders-chrome-'));
const chrome = spawn(process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe', [
  `--user-data-dir=${profile}`, '--remote-debugging-port=0', '--no-first-run',
  '--no-default-browser-check', '--window-size=1100,820', '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows',
  '--disable-features=CalculateNativeWinOcclusion', 'about:blank'], { stdio: 'ignore' });
const pause = ms => new Promise(done => setTimeout(done, ms));
let socket;
try {
  let port;
  for (let attempt = 0; attempt < 80; attempt++) {
    try { port = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break; }
    catch { await pause(250); }
  }
  if (!port) throw new Error('Chrome debugging endpoint did not start');
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(tabs.find(t => t.type === 'page').webSocketDebuggerUrl);
  await new Promise(done => socket.addEventListener('open', done, { once: true }));
  let id = 0, events = [], traceDone, checkResult, pageLabel = '';
  const errors = [];
  const pending = new Map();
  socket.addEventListener('message', event => {
    const data = JSON.parse(event.data);
    if (data.id) {
      const p = pending.get(data.id); pending.delete(data.id);
      if (data.error) p.reject(new Error(JSON.stringify(data.error))); else p.resolve(data.result);
    } else if (data.method === 'Tracing.dataCollected') events.push(...data.params.value);
    else if (data.method === 'Tracing.tracingComplete') traceDone?.();
    else if (data.method === 'Runtime.consoleAPICalled') {
      const text = data.params.args.map(a => a.value || a.description || '').join(' ');
      if (/^(PASS|FAIL):/.test(text)) checkResult = text;
      if (data.params.type === 'error') { errors.push({ pageLabel, text }); console.log(text); }
    } else if (data.method === 'Runtime.exceptionThrown') {
      const text = data.params.exceptionDetails.exception?.description || data.params.exceptionDetails.text;
      errors.push({ pageLabel, text }); console.log(text);
    }
  });
  function call(method, params = {}) {
    return new Promise((resolve, reject) => {
      pending.set(++id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });
  }
  await call('Page.enable'); await call('Runtime.enable'); await call('Performance.enable');
  await call('Emulation.setFocusEmulationEnabled', { enabled: true });
  const version = await call('Browser.getVersion');
  const runs = [];
  for (let run = 1; run <= (process.env.CHECK_ONLY ? 0 : 3); run++) {
    for (const variant of variants) {
      pageLabel = `${variant}-${run}`;
      await call('Page.navigate', { url: 'about:blank' }); await pause(500);
      await call('Page.navigate', { url: `http://127.0.0.1:${webPort}/${variant}/` });
      await pause(8000);
      await call('Page.bringToFront');
      const viewport = (await call('Runtime.evaluate', { expression:
        '({width: innerWidth, height: innerHeight, dpr: devicePixelRatio})', returnByValue: true })).result.value;
      if (run === 1) {
        const shot = await call('Page.captureScreenshot');
        await writeFile(join(output, `${variant}.png`), Buffer.from(shot.data, 'base64'));
      }
      events = [];
      await call('Tracing.start', { categories: 'devtools.timeline,cc,gpu,viz,benchmark', transferMode: 'ReportEvents' });
      const start = await call('Performance.getMetrics');
      await pause(8000);
      const end = await call('Performance.getMetrics');
      const complete = new Promise(done => { traceDone = done; });
      await call('Tracing.end'); await complete;
      const metrics = Object.fromEntries(end.metrics.map(m => [m.name, m.value]));
      for (const m of start.metrics) metrics[m.name] -= m.value;
      const sums = {};
      for (const e of events) if (e.ph === 'X' && e.dur) sums[e.name] = (sums[e.name] || 0) + e.dur / 1000;
      const callbacks = events.filter(e => e.name === 'FireAnimationFrame' && e.ph === 'X');
      const callbackDurations = callbacks.map(e => e.dur / 1000).sort((a, b) => a - b);
      const record = { variant, run, viewport, windowSeconds: metrics.Timestamp,
        taskMs: metrics.TaskDuration * 1000,
        scriptMs: metrics.ScriptDuration * 1000,
        animationCallbacks: callbacks.length,
        callbackMs: callbacks.reduce((sum, e) => sum + e.dur / 1000, 0),
        callbackMedianMs: callbackDurations[Math.floor(callbackDurations.length / 2)],
        callbackP95Ms: callbackDurations[Math.floor(callbackDurations.length * 0.95)],
        displayFrameEvents: events.filter(e => e.name === 'Display::FrameDisplayed').length,
        gpuCommandMs: sums['CommandBufferStub::OnAsyncFlush'] || 0,
        compositorPaintMs: sums['SkiaOutputSurfaceImplOnGpu::FinishPaintRenderPass'] || 0 };
      runs.push(record); console.log(JSON.stringify(record));
      await writeFile(join(output, `${variant}-${run}.json`), JSON.stringify({ traceEvents: events }));
      if (callbacks.length < 30) {
        const shot = await call('Page.captureScreenshot');
        await writeFile(join(output, `${variant}-${run}-inactive.png`), Buffer.from(shot.data, 'base64'));
        throw new Error(`Inactive animation: ${pageLabel}. Timing rejected.`);
      }
    }
  }
  pageLabel = 'check';
  await call('Page.navigate', { url: `http://127.0.0.1:${webPort}/check/` });
  for (let attempt = 0; attempt < 120 && !checkResult; attempt++) await pause(500);
  if (!checkResult) throw new Error('Browser coverage checks did not report a result');
  console.log(checkResult);
  await writeFile(join(output, 'summary.json'), JSON.stringify({ version, runs, errors, checkResult }, null, 2));
  await call('Browser.close').catch(() => {});
  if (!checkResult.startsWith('PASS:')) process.exitCode = 1;
} finally {
  socket?.close(); server.close(); chrome.kill();
}
