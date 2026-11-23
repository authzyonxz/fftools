'use strict';
// FFPatch catalogue server — zero dependencies, Node >= 18.
//
//   ADMIN_TOKEN=... MASTER_SECRET=... node server.js
//
// Public:   GET /api/catalog            → manifest + payload file list for the app
//           GET /f/<fileId>.fpp         → encrypted payload file (FPP1)
//           GET /                       → admin panel (public/ folder)
// Admin:    header  x-admin-token: <ADMIN_TOKEN>
//           GET    /api/admin/state
//           POST   /api/admin/functions                { id, name, subtitle, groupId, status, games, locate }
//           DELETE /api/admin/functions/:id
//           POST   /api/admin/functions/:id/status      { status: active|maintenance|disabled }
//           POST   /api/admin/functions/:id/games       { games: [gameId...] }
//           POST   /api/admin/functions/:id/locate      { mode, names, roots, maxMatches }
//           POST   /api/admin/functions/:id/files/:gameId   body = ZIP (raw bytes, application/zip)
//           DELETE /api/admin/functions/:id/files/:gameId
//           POST   /api/admin/games                     { games: [...] }
//           GET    /api/admin/audit

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const { Store } = require('./lib/store');
const { extractZip, ZipError } = require('./lib/zip');
const { encryptFile, decryptFile, sha256Hex } = require('./lib/crypto');

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '127.0.0.1';
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const MASTER_SECRET = process.env.MASTER_SECRET || '';
const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(__dirname, 'data'));
const PUBLIC_DIR = path.join(__dirname, 'public');
const BASE_URL = (process.env.PUBLIC_URL || '').replace(/\/+$/, '');
const MAX_UPLOAD = Number(process.env.MAX_UPLOAD_BYTES || 25 * 1024 * 1024);

if (ADMIN_TOKEN.length < 8) {
  console.error('erro: defina ADMIN_TOKEN (>= 8 caracteres)');
  process.exit(1);
}
if (MASTER_SECRET.length < 16) {
  console.error('erro: defina MASTER_SECRET (>= 16 caracteres). sem ele o formato FPP1 não fecha.');
  process.exit(1);
}

const store = new Store(DATA_DIR);

function json(response, status, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': body.length,
    'cache-control': 'no-store'
  });
  response.end(body);
}

function fail(response, status, message) {
  json(response, status, { ok: false, error: message });
}

function readBody(request, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new Error('corpo grande demais'));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => resolve(Buffer.concat(chunks)));
    request.on('error', reject);
  });
}

async function readJson(request) {
  const raw = await readBody(request, 512 * 1024);
  if (raw.length === 0) return {};
  return JSON.parse(raw.toString('utf8'));
}

function authorised(request) {
  const header = request.headers['x-admin-token'];
  if (typeof header !== 'string' || header.length !== ADMIN_TOKEN.length) return false;
  return crypto.timingSafeEqual(Buffer.from(header), Buffer.from(ADMIN_TOKEN));
}

function baseUrl(request) {
  if (BASE_URL) return BASE_URL;
  const forwardedProto = request.headers['x-forwarded-proto'];
  const protocol = typeof forwardedProto === 'string' ? forwardedProto.split(',')[0] : 'http';
  const host = request.headers['x-forwarded-host'] || request.headers.host || `127.0.0.1:${PORT}`;
  return `${protocol}://${host}`;
}

function publicGame(game) {
  return { id: game.id, name: game.name, bundle: game.bundle, icon: game.icon, root: game.root || 'data' };
}

/*! Builds the catalogue in the exact shape the app turns into FFManifest. */
function buildCatalog(request) {
  const origin = baseUrl(request);
  const groups = store.db.groups.map((group) => ({
    id: group.id,
    title: group.title,
    exclusive: Boolean(group.exclusive),
    functions: []
  }));
  const groupIndex = new Map(groups.map((group) => [group.id, group]));

  for (const entry of store.db.functions) {
    if (entry.status === 'disabled') continue;
    const assets = {};
    for (const gameId of entry.games) {
      const published = entry.files[gameId];
      if (!published || !published.files || published.files.length === 0) continue;
      assets[gameId] = published.files.map((file) => ({
        path: file.path,
        size: file.size,
        sha256: file.sha256,
        url: `${origin}/f/${file.fileId}.fpp`
      }));
    }
    if (Object.keys(assets).length === 0) continue;

    const group = groupIndex.get(entry.groupId) || groupIndex.values().next().value;
    if (!group) continue;
    group.functions.push({
      id: entry.id,
      name: entry.name,
      subtitle: entry.subtitle,
      payload: entry.id,
      locate: entry.locate,
      games: entry.games,
      status: entry.status,
      assets
    });
  }

  return {
    schema: 1,
    version: store.db.version,
    updatedAt: store.db.updatedAt,
    games: store.db.games.map(publicGame),
    groups: groups.filter((group) => group.functions.length > 0),
    envelope: 'FPP1',
    cipher: 'aes-256-cbc+hmac-sha256'
  };
}

function writeStatic(response, filePath) {
  const types = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.svg': 'image/svg+xml'
  };
  fs.readFile(filePath, (error, data) => {
    if (error) {
      response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
      response.end('não encontrado');
      return;
    }
    response.writeHead(200, {
      'content-type': types[path.extname(filePath)] || 'application/octet-stream',
      'content-length': data.length,
      'cache-control': 'no-store'
    });
    response.end(data);
  });
}

async function handle(request, response) {
  const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
  const { pathname } = url;
  const method = request.method || 'GET';

  if (method === 'GET' && pathname === '/api/health') {
    json(response, 200, { ok: true, version: store.db.version, functions: store.db.functions.length });
    return;
  }

  if (method === 'GET' && pathname === '/api/catalog') {
    json(response, 200, buildCatalog(request));
    return;
  }

  const packMatch = pathname.match(/^\/f\/([A-Za-z0-9-]+)\.fpp$/);
  if (method === 'GET' && packMatch) {
    const fileId = packMatch[1];
    for (const entry of store.db.functions) {
      for (const gameId of Object.keys(entry.files)) {
        const file = entry.files[gameId].files.find((candidate) => candidate.fileId === fileId);
        if (!file) continue;
        const packPath = path.join(store.packsDir, entry.id, gameId, `${fileId}.fpp`);
        if (!fs.existsSync(packPath)) {
          fail(response, 404, 'pack expirado');
          return;
        }
        const data = fs.readFileSync(packPath);
        response.writeHead(200, {
          'content-type': 'application/octet-stream',
          'content-length': data.length,
          'cache-control': 'public, max-age=60'
        });
        response.end(data);
        return;
      }
    }
    fail(response, 404, 'pack desconhecido');
    return;
  }

  // ---- admin ---------------------------------------------------------------
  if (pathname.startsWith('/api/admin/')) {
    if (!authorised(request)) {
      fail(response, 401, 'token inválido');
      return;
    }

    if (method === 'GET' && pathname === '/api/admin/state') {
      json(response, 200, {
        ok: true,
        db: store.db,
        catalogURL: `${baseUrl(request)}/api/catalog`,
        packsDir: store.packsDir
      });
      return;
    }

    if (method === 'GET' && pathname === '/api/admin/audit') {
      json(response, 200, { ok: true, audit: store.db.audit });
      return;
    }

    if (method === 'POST' && pathname === '/api/admin/functions') {
      const body = await readJson(request);
      if (!/^0x[0-9A-Fa-f]{4}$/.test(body.id || '')) {
        fail(response, 400, 'id deve ser 0xNNNN');
        return;
      }
      if (!body.name || String(body.name).trim().length === 0) {
        fail(response, 400, 'nome obrigatório');
        return;
      }
      store.upsertFunction({
        id: body.id,
        name: String(body.name).trim(),
        subtitle: body.subtitle ? String(body.subtitle).trim() : '',
        groupId: body.groupId,
        status: body.status,
        games: body.games,
        locate: sanitizeLocate(body.locate)
      });
      store.save();
      json(response, 200, { ok: true });
      return;
    }

    const functionMatch = pathname.match(/^\/api\/admin\/functions\/(0x[0-9A-Fa-f]{4})(?:\/(.*))?$/);
    if (functionMatch) {
      const functionId = functionMatch[1];
      const rest = functionMatch[2] || '';

      if (method === 'DELETE' && rest === '') {
        if (!store.removeFunction(functionId)) {
          fail(response, 404, 'função não existe');
          return;
        }
        store.save();
        json(response, 200, { ok: true });
        return;
      }

      if (method === 'POST' && rest === 'status') {
        const body = await readJson(request);
        if (!['active', 'maintenance', 'disabled'].includes(body.status)) {
          fail(response, 400, 'status inválido');
          return;
        }
        if (!store.setStatus(functionId, body.status)) {
          fail(response, 404, 'função não existe');
          return;
        }
        store.save();
        json(response, 200, { ok: true });
        return;
      }

      if (method === 'POST' && rest === 'games') {
        const body = await readJson(request);
        if (!Array.isArray(body.games)) {
          fail(response, 400, 'games deve ser lista');
          return;
        }
        if (!store.setGames(functionId, body.games)) {
          fail(response, 404, 'função não existe');
          return;
        }
        store.save();
        json(response, 200, { ok: true });
        return;
      }

      if (method === 'POST' && rest === 'locate') {
        const body = await readJson(request);
        if (!store.setLocate(functionId, sanitizeLocate(body))) {
          fail(response, 404, 'função não existe');
          return;
        }
        store.save();
        json(response, 200, { ok: true });
        return;
      }

      const filesMatch = rest.match(/^files\/([A-Za-z0-9_.-]+)$/);
      if (filesMatch) {
        const gameId = filesMatch[1];
        if (!store.gameById(gameId)) {
          fail(response, 404, 'jogo desconhecido');
          return;
        }

        if (method === 'DELETE') {
          if (!store.clearFiles(functionId, gameId)) {
            fail(response, 404, 'nada publicado para esse jogo');
            return;
          }
          store.save();
          json(response, 200, { ok: true });
          return;
        }

        if (method === 'POST') {
          const body = await readBody(request, MAX_UPLOAD);
          if (body.length === 0) {
            fail(response, 400, 'corpo vazio: envie o ZIP do payload');
            return;
          }
          let extracted;
          try {
            extracted = extractZip(body);
          } catch (error) {
            fail(response, 400, error instanceof ZipError ? error.message : 'ZIP inválido');
            return;
          }

          const targetDir = path.join(store.packsDir, functionId, gameId);
          fs.rmSync(targetDir, { recursive: true, force: true });
          fs.mkdirSync(targetDir, { recursive: true });

          const records = [];
          for (const file of extracted) {
            const fileId = crypto.randomUUID();
            const pack = encryptFile(file.data, { secret: MASTER_SECRET, functionId, gameId });
            fs.writeFileSync(path.join(targetDir, `${fileId}.fpp`), pack);
            records.push({
              path: file.path,
              size: file.data.length,
              sha256: sha256Hex(file.data),
              fileId
            });
          }

          // Round-trip guard: a pack that cannot be decrypted with the same
          // secret must never reach the catalogue.
          for (const record of records) {
            const packPath = path.join(targetDir, `${record.fileId}.fpp`);
            const restored = decryptFile(fs.readFileSync(packPath), { secret: MASTER_SECRET, functionId, gameId });
            if (sha256Hex(restored) !== record.sha256) {
              fail(response, 500, 'falha no round-trip da criptografia');
              return;
            }
          }

          store.setFiles(functionId, gameId, records);
          store.save();
          json(response, 200, { ok: true, files: records.map(({ path: filePath, size, sha256 }) => ({ path: filePath, size, sha256 })) });
          return;
        }
      }

      fail(response, 404, 'rota admin desconhecida');
      return;
    }

    if (method === 'POST' && pathname === '/api/admin/games') {
      const body = await readJson(request);
      if (!Array.isArray(body.games) || body.games.length === 0) {
        fail(response, 400, 'games deve ser lista não vazia');
        return;
      }
      const games = body.games
        .filter((game) => game && typeof game.id === 'string' && typeof game.bundle === 'string')
        .map((game) => ({
          id: game.id,
          name: String(game.name || game.id),
          bundle: String(game.bundle),
          icon: String(game.icon || (game.id === 'freefiremax' ? 'ic_game_max' : 'ic_game_normal')),
          root: game.root === 'bundle' ? 'bundle' : 'data'
        }));
      if (games.length === 0) {
        fail(response, 400, 'nenhum jogo válido');
        return;
      }
      store.db.games = games;
      store.bump();
      store.audit('games', games.map((game) => `${game.id}:${game.bundle}`).join(' '));
      store.save();
      json(response, 200, { ok: true });
      return;
    }

    fail(response, 404, 'rota admin desconhecida');
    return;
  }

  // ---- static --------------------------------------------------------------
  if (method === 'GET') {
    const relative = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
    const filePath = path.join(PUBLIC_DIR, relative);
    if (!filePath.startsWith(PUBLIC_DIR)) {
      fail(response, 403, 'proibido');
      return;
    }
    writeStatic(response, filePath);
    return;
  }

  fail(response, 404, 'não encontrado');
}

function sanitizeLocate(raw) {
  const locate = raw && typeof raw === 'object' ? raw : {};
  const mode = ['path', 'name', 'path-or-name'].includes(locate.mode) ? locate.mode : 'path-or-name';
  const names = Array.isArray(locate.names)
    ? locate.names.filter((name) => typeof name === 'string' && name.length > 0 && !name.includes('/')).slice(0, 32)
    : [];
  const roots = Array.isArray(locate.roots)
    ? locate.roots.filter((root) => typeof root === 'string' && root.length > 0 && !root.startsWith('/') && !root.includes('..')).slice(0, 8)
    : [];
  let maxMatches = Number(locate.maxMatches || 8);
  if (!Number.isFinite(maxMatches) || maxMatches < 1) maxMatches = 8;
  maxMatches = Math.min(Math.floor(maxMatches), 64);
  return { mode, names, roots, maxMatches };
}

const server = http.createServer((request, response) => {
  handle(request, response).catch((error) => {
    console.error('erro:', error);
    if (!response.headersSent) fail(response, 500, 'erro interno');
  });
});

server.listen(PORT, HOST, () => {
  console.log(`FFPatch catalogue em http://${HOST}:${PORT}`);
  console.log(`admin: ${BASE_URL || `http://127.0.0.1:${PORT}`}/`);
  console.log(`catálogo: ${BASE_URL || `http://127.0.0.1:${PORT}`}/api/catalog`);
  console.log(`dados: ${DATA_DIR}`);
});

module.exports = { server, buildCatalog };
