'use strict';
// End-to-end self-test of the catalogue server + FPP1 container.
//
//   node scripts/selftest.js
//
// Spawns the server on a random port with a temporary data dir, publishes a ZIP
// payload, reads the catalog, downloads a pack, decrypts it with the same code
// path the app mirrors, flips a function to maintenance, removes it, and exits
// non-zero if anything does not line up. No external dependency.

const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');

const { decryptFile, sha256Hex } = require('../lib/crypto');

const SECRET = 'selftest-master-secret-32-bytes!!';
const TOKEN = 'selftest-admin-token';
const ROOT = path.join(__dirname, '..');

function fail(message) {
  console.error(`FALHOU: ${message}`);
  process.exit(1);
}

function makeZip(files) {
  // Minimal stored-ZIP writer (no compression) so the test does not shell out.
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const file of files) {
    const name = Buffer.from(file.name, 'utf8');
    const data = Buffer.from(file.data);
    const crc = zlib.crc32 ? zlib.crc32(data) : 0;
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0, 6);
    local.writeUInt16LE(0, 8);       // stored
    local.writeUInt16LE(0, 10);
    local.writeUInt16LE(0, 12);
    local.writeUInt32LE(crc >>> 0, 14);
    local.writeUInt32LE(data.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    locals.push(local, name, data);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0, 8);
    central.writeUInt16LE(0, 10);    // stored
    central.writeUInt16LE(0, 12);
    central.writeUInt16LE(0, 14);
    central.writeUInt32LE(crc >>> 0, 16);
    central.writeUInt32LE(data.length, 20);
    central.writeUInt32LE(data.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(offset, 42);
    centrals.push(central, name);

    offset += 30 + name.length + data.length;
  }

  const centralBuffer = Buffer.concat(centrals);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(files.length, 8);
  eocd.writeUInt16LE(files.length, 10);
  eocd.writeUInt32LE(centralBuffer.length, 12);
  eocd.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, centralBuffer, eocd]);
}

async function main() {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ffpatch-catalog-'));
  const port = 19000 + Math.floor(Math.random() * 800);
  const origin = `http://127.0.0.1:${port}`;

  const child = spawn(process.execPath, [path.join(ROOT, 'server.js')], {
    env: { ...process.env, PORT: String(port), ADMIN_TOKEN: TOKEN, MASTER_SECRET: SECRET, DATA_DIR: dataDir },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let serverLog = '';
  child.stdout.on('data', (chunk) => { serverLog += chunk; });
  child.stderr.on('data', (chunk) => { serverLog += chunk; });

  const stop = () => {
    child.kill();
    fs.rmSync(dataDir, { recursive: true, force: true });
  };

  try {
    let ready = false;
    for (let attempt = 0; attempt < 60; attempt++) {
      try {
        const response = await fetch(`${origin}/api/health`);
        if (response.ok) { ready = true; break; }
      } catch { /* ainda subindo */ }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    if (!ready) fail(`servidor não subiu\n${serverLog}`);

    const health = await (await fetch(`${origin}/api/health`)).json();
    if (health.functions !== 6) fail(`esperava 6 funções seed, veio ${health.functions}`);

    const catalogEmpty = await (await fetch(`${origin}/api/catalog`)).json();
    if (catalogEmpty.groups.length !== 0) fail('catálogo deveria começar sem funções publicadas');

    // ---- publish -----------------------------------------------------------
    const payload = makeZip([
      { name: 'Documents/ffpatch/hs_alto.cfg', data: 'mode=hs_alto\n' },
      { name: 'Documents/ffpatch/hs_alto.json', data: '{"function":"0x1001"}\n' }
    ]);

    const upload = await fetch(`${origin}/api/admin/functions/0x1001/files/freefireth`, {
      method: 'POST',
      headers: { 'x-admin-token': TOKEN, 'content-type': 'application/zip' },
      body: payload
    });
    if (!upload.ok) fail(`upload falhou: ${upload.status} ${await upload.text()}`);
    const uploaded = await upload.json();
    if (uploaded.files.length !== 2) fail('esperava 2 arquivos publicados');

    // ---- catalog -----------------------------------------------------------
    const catalog = await (await fetch(`${origin}/api/catalog`)).json();
    const group = catalog.groups.find((entry) => entry.id === 'aimbot');
    if (!group) fail('grupo aimbot ausente no catálogo');
    const functionEntry = group.functions.find((entry) => entry.id === '0x1001');
    if (!functionEntry) fail('0x1001 ausente no catálogo após publicar');
    const assets = functionEntry.assets.freefireth;
    if (!assets || assets.length !== 2) fail('assets do freefireth errados');
    if (functionEntry.games.join(',') !== 'freefireth,freefiremax') fail('games do seed errados');

    // ---- download + decrypt (mirrors the iOS client) -----------------------
    for (const asset of assets) {
      const packResponse = await fetch(asset.url);
      if (!packResponse.ok) fail(`download do pack falhou: ${packResponse.status}`);
      const pack = Buffer.from(await packResponse.arrayBuffer());
      if (pack.subarray(0, 4).toString('ascii') !== 'FPP1') fail('magic FPP1 ausente');
      const plain = decryptFile(pack, { secret: SECRET, functionId: '0x1001', gameId: 'freefireth' });
      if (sha256Hex(plain) !== asset.sha256) fail(`sha256 divergente em ${asset.path}`);
      if (plain.length !== asset.size) fail(`tamanho divergente em ${asset.path}`);
    }

    // wrong secret must fail
    const firstPack = Buffer.from(await (await fetch(assets[0].url)).arrayBuffer());
    let rejected = false;
    try {
      decryptFile(firstPack, { secret: 'outro-segredo-qualquer-123', functionId: '0x1001', gameId: 'freefireth' });
    } catch {
      rejected = true;
    }
    if (!rejected) fail('pacote aceito com segredo errado — HMAC não está validando');

    // ---- maintenance + games ----------------------------------------------
    const statusResponse = await fetch(`${origin}/api/admin/functions/0x1001/status`, {
      method: 'POST',
      headers: { 'x-admin-token': TOKEN, 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'maintenance' })
    });
    if (!statusResponse.ok) fail('mudança de status falhou');
    const catalogMaintenance = await (await fetch(`${origin}/api/catalog`)).json();
    const maintenanceEntry = catalogMaintenance.groups
      .flatMap((entry) => entry.functions)
      .find((entry) => entry.id === '0x1001');
    if (!maintenanceEntry || maintenanceEntry.status !== 'maintenance') fail('status maintenance não refletiu');

    const gamesResponse = await fetch(`${origin}/api/admin/functions/0x1001/games`, {
      method: 'POST',
      headers: { 'x-admin-token': TOKEN, 'content-type': 'application/json' },
      body: JSON.stringify({ games: ['freefiremax'] })
    });
    if (!gamesResponse.ok) fail('mudança de games falhou');

    // ---- auth guard --------------------------------------------------------
    const unauthorised = await fetch(`${origin}/api/admin/state`);
    if (unauthorised.status !== 401) fail(`admin sem token deveria dar 401, veio ${unauthorised.status}`);

    // ---- unpublish + delete ------------------------------------------------
    const remove = await fetch(`${origin}/api/admin/functions/0x1001/files/freefireth`, {
      method: 'DELETE',
      headers: { 'x-admin-token': TOKEN }
    });
    if (!remove.ok) fail('unpublish falhou');
    const catalogAfter = await (await fetch(`${origin}/api/catalog`)).json();
    if (catalogAfter.groups.length !== 0) fail('catálogo deveria ficar vazio após unpublish');

    console.log('OK — catálogo, upload ZIP, FPP1, HMAC, status, games, auth e unpublish');
    stop();
    process.exit(0);
  } catch (error) {
    console.error(error);
    console.error(serverLog);
    stop();
    process.exit(1);
  }
}

main();
