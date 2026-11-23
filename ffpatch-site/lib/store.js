'use strict';
// JSON store with atomic writes. One file: <DATA_DIR>/db.json.
// It is intentionally boring: a site this size does not need a database, and a
// single JSON file means the operator can copy the whole catalogue anywhere.

const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_GAMES = [
  { id: 'freefireth', name: 'Free Fire Normal', bundle: 'com.dts.freefireth', icon: 'ic_game_normal', root: 'data' },
  { id: 'freefiremax', name: 'Free Fire Max', bundle: 'com.dts.freefiremax', icon: 'ic_game_max', root: 'data' }
];

const DEFAULT_GROUPS = [
  { id: 'aimbot', title: 'Funções de Aimbot', exclusive: true },
  { id: 'hologram', title: 'Funções de Holograma', exclusive: false }
];

const DEFAULT_FUNCTIONS = [
  { id: '0x1001', name: 'HS ALTO', subtitle: 'HS Acima da Cabeça do Inimigo.', groupId: 'aimbot' },
  { id: '0x1002', name: 'HS ALTO + PESCOÇO', subtitle: 'HS Acima da Cabeça e no Pescoço.', groupId: 'aimbot' },
  { id: '0x1003', name: 'HS PESCOÇO', subtitle: 'HS Apenas no Pescoço do Inimigo.', groupId: 'aimbot' },
  { id: '0x1004', name: 'HS CAVEIRA', subtitle: 'HS Abaixo do Pescoço do Inimigo.', groupId: 'aimbot' },
  { id: '0x1005', name: 'HS PEITO', subtitle: 'HS no Peito do Inimigo.', groupId: 'aimbot' },
  { id: '0x2001', name: 'HOLOGRAMA ARMAS', subtitle: 'Usar Gráfico no Padrão Para Funcionar.', groupId: 'hologram' }
];

class Store {
  constructor(dataDir) {
    this.dataDir = dataDir;
    this.packsDir = path.join(dataDir, 'packs');
    this.dbPath = path.join(dataDir, 'db.json');
    fs.mkdirSync(this.packsDir, { recursive: true });
    this.db = this.load();
  }

  load() {
    if (fs.existsSync(this.dbPath)) {
      const parsed = JSON.parse(fs.readFileSync(this.dbPath, 'utf8'));
      return this.normalize(parsed);
    }
    const seeded = this.normalize({
      schema: 1,
      version: 1,
      games: DEFAULT_GAMES,
      groups: DEFAULT_GROUPS,
      functions: DEFAULT_FUNCTIONS.map((entry) => ({
        ...entry,
        status: 'active',
        games: DEFAULT_GAMES.map((game) => game.id),
        locate: { mode: 'path-or-name', names: [], maxMatches: 8 },
        files: {}
      })),
      audit: []
    });
    this.write(seeded);
    return seeded;
  }

  normalize(db) {
    const functions = (db.functions || []).map((entry) => ({
      id: entry.id,
      name: entry.name || entry.id,
      subtitle: entry.subtitle || '',
      groupId: entry.groupId || 'aimbot',
      status: entry.status || 'active',
      games: Array.isArray(entry.games) && entry.games.length ? entry.games : DEFAULT_GAMES.map((game) => game.id),
      locate: entry.locate || { mode: 'path-or-name', names: [], maxMatches: 8 },
      files: entry.files || {}
    }));
    return {
      schema: 1,
      version: db.version || 1,
      updatedAt: db.updatedAt || new Date().toISOString(),
      games: db.games && db.games.length ? db.games : DEFAULT_GAMES,
      groups: db.groups && db.groups.length ? db.groups : DEFAULT_GROUPS,
      functions,
      audit: Array.isArray(db.audit) ? db.audit.slice(0, 400) : []
    };
  }

  write(db) {
    this.db = db;
    this.db.updatedAt = new Date().toISOString();
    const temporary = `${this.dbPath}.tmp`;
    fs.writeFileSync(temporary, JSON.stringify(this.db, null, 2));
    fs.renameSync(temporary, this.dbPath);
  }

  audit(action, detail) {
    this.db.audit.unshift({ at: new Date().toISOString(), action, detail: detail || '' });
    if (this.db.audit.length > 400) this.db.audit.length = 400;
  }

  bump() {
    this.db.version = (this.db.version || 0) + 1;
  }

  functionById(id) {
    return this.db.functions.find((entry) => entry.id === id) || null;
  }

  gameById(id) {
    return this.db.games.find((entry) => entry.id === id) || null;
  }

  upsertFunction(payload) {
    const existing = this.functionById(payload.id);
    const record = {
      id: payload.id,
      name: payload.name,
      subtitle: payload.subtitle || '',
      groupId: payload.groupId || 'aimbot',
      status: payload.status || (existing ? existing.status : 'active'),
      games: Array.isArray(payload.games) && payload.games.length
        ? payload.games.filter((gameId) => this.gameById(gameId) !== null)
        : (existing ? existing.games : this.db.games.map((game) => game.id)),
      locate: payload.locate || (existing ? existing.locate : { mode: 'path-or-name', names: [], maxMatches: 8 }),
      files: existing ? existing.files : {}
    };
    if (existing) {
      Object.assign(existing, record);
    } else {
      this.db.functions.push(record);
    }
    this.bump();
    this.audit(existing ? 'update-function' : 'create-function', `${record.id} ${record.name}`);
  }

  removeFunction(id) {
    const index = this.db.functions.findIndex((entry) => entry.id === id);
    if (index < 0) return false;
    const [removed] = this.db.functions.splice(index, 1);
    fs.rmSync(path.join(this.packsDir, id), { recursive: true, force: true });
    this.bump();
    this.audit('delete-function', `${removed.id} ${removed.name}`);
    return true;
  }

  setStatus(id, status) {
    const entry = this.functionById(id);
    if (!entry) return false;
    entry.status = status;
    this.bump();
    this.audit('status', `${id} → ${status}`);
    return true;
  }

  setGames(id, games) {
    const entry = this.functionById(id);
    if (!entry) return false;
    entry.games = games.filter((gameId) => this.gameById(gameId) !== null);
    this.bump();
    this.audit('games', `${id} → ${entry.games.join(',') || 'nenhum'}`);
    return true;
  }

  setLocate(id, locate) {
    const entry = this.functionById(id);
    if (!entry) return false;
    entry.locate = locate;
    this.bump();
    this.audit('locate', `${id} → ${JSON.stringify(locate)}`);
    return true;
  }

  setFiles(id, gameId, files) {
    const entry = this.functionById(id);
    if (!entry) return false;
    entry.files[gameId] = { publishedAt: new Date().toISOString(), files };
    this.bump();
    this.audit('publish', `${id}/${gameId} → ${files.length} arquivo(s)`);
    return true;
  }

  clearFiles(id, gameId) {
    const entry = this.functionById(id);
    if (!entry || !entry.files[gameId]) return false;
    for (const file of entry.files[gameId].files) {
      fs.rmSync(path.join(this.packsDir, id, gameId, `${file.fileId}.fpp`), { force: true });
    }
    delete entry.files[gameId];
    this.bump();
    this.audit('unpublish', `${id}/${gameId}`);
    return true;
  }

  save() {
    this.write(this.db);
  }
}

module.exports = { Store };
