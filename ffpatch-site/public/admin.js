'use strict';

const state = {
  token: localStorage.getItem('ffpatch-token') || '',
  db: null,
  catalogURL: ''
};

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

function toast(message) {
  let element = $('#toast');
  if (!element) {
    element = document.createElement('div');
    element.id = 'toast';
    document.body.appendChild(element);
  }
  element.textContent = message;
  element.classList.add('show');
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => element.classList.remove('show'), 2600);
}

async function api(path, options = {}) {
  const headers = Object.assign({ 'x-admin-token': state.token }, options.headers || {});
  const requestURL = new URL(path.replace(/^\/+/, ''), document.baseURI);
  const response = await fetch(requestURL, Object.assign({}, options, { headers }));
  const text = await response.text();
  let payload = null;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch {
    payload = { ok: false, error: text };
  }
  if (!response.ok || (payload && payload.ok === false)) {
    throw new Error((payload && payload.error) || `HTTP ${response.status}`);
  }
  return payload;
}

async function loadState() {
  const data = await api('/api/admin/state');
  state.db = data.db;
  state.catalogURL = data.catalogURL;
  renderAll();
}

function renderAll() {
  $('#login-panel').classList.add('hidden');
  ['catalog-panel', 'games-panel', 'functions-panel', 'audit-panel'].forEach((id) => {
    $(`#${id}`).classList.remove('hidden');
  });
  $('#catalog-url').value = state.catalogURL;
  $('#open-catalog').href = state.catalogURL;
  $('#catalog-version').textContent = state.db.version;
  renderGames();
  renderFunctions();
  renderAudit();
}

function renderGames() {
  const container = $('#games-editor');
  container.innerHTML = '';
  for (const game of state.db.games) {
    const card = document.createElement('div');
    card.className = 'game-card';
    card.dataset.gameId = game.id;
    card.innerHTML = `
      <div class="id">${game.id}</div>
      <label class="field"><span>Bundle ID do jogo</span>
        <input class="input" data-field="bundle" value="${escapeAttribute(game.bundle)}">
      </label>
      <label class="field"><span>nome</span>
        <input class="input" data-field="name" value="${escapeAttribute(game.name)}">
      </label>
      <label class="field"><span>Onde ficam os arquivos do jogo?</span>
        <select class="input" data-field="root">
          <option value="data"${game.root === 'data' ? ' selected' : ''}>Container de dados do jogo (recomendado)</option>
          <option value="bundle"${game.root === 'bundle' ? ' selected' : ''}>Dentro do aplicativo instalado (.app)</option>
        </select>
      </label>`;
    container.appendChild(card);
  }
}

async function saveGames() {
  const games = $$('#games-editor .game-card').map((card) => ({
    id: card.dataset.gameId,
    name: $('[data-field="name"]', card).value.trim(),
    bundle: $('[data-field="bundle"]', card).value.trim(),
    root: $('[data-field="root"]', card).value,
    icon: card.dataset.gameId === 'freefiremax' ? 'ic_game_max' : 'ic_game_normal'
  }));
  try {
    await api('/api/admin/games', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ games })
    });
    await loadState();
    toast('jogos salvos');
  } catch (error) {
    toast(error.message);
  }
}

function renderFunctions() {
  const container = $('#functions');
  container.innerHTML = '';
  const template = $('#function-template');
  const groupOptions = state.db.groups
    .map((group) => `<option value="${group.id}">${group.title}</option>`)
    .join('');

  for (const entry of state.db.functions) {
    const node = template.content.firstElementChild.cloneNode(true);
    node.dataset.id = entry.id;
    $('[data-field="id"]', node).textContent = entry.id;
    $('[data-field="name"]', node).value = entry.name;
    $('[data-field="subtitle"]', node).value = entry.subtitle || '';
    $('[data-field="groupId"]', node).innerHTML = groupOptions;
    $('[data-field="groupId"]', node).value = entry.groupId;
    $('[data-field="status"]', node).value = entry.status;

    const gamesBox = $('[data-field="games"]', node);
    for (const game of state.db.games) {
      const label = document.createElement('label');
      label.innerHTML = `<input type="checkbox" value="${game.id}"${entry.games.includes(game.id) ? ' checked' : ''}> ${game.name}`;
      gamesBox.appendChild(label);
    }

    const locate = entry.locate || { mode: 'path-or-name', names: [], roots: [], maxMatches: 8 };
    $('[data-field="locateMode"]', node).value = locate.mode;
    $('[data-field="locateNames"]', node).value = (locate.names || []).join(',');
    $('[data-field="locateRoots"]', node).value = (locate.roots || []).join(',');
    $('[data-field="maxMatches"]', node).value = locate.maxMatches || 8;

    renderPublishRows($('[data-field="publish"]', node), entry);

    $('[data-action="save"]', node).addEventListener('click', () => saveFunction(node, entry.id));
    $('[data-action="delete"]', node).addEventListener('click', () => deleteFunction(entry.id, entry.name));

    container.appendChild(node);
  }
}

function renderPublishRows(container, entry) {
  container.innerHTML = '';
  for (const game of state.db.games) {
    const published = entry.files && entry.files[game.id];
    const row = document.createElement('div');
    row.className = 'publish-row';

    const meta = published
      ? `${published.files.length} arquivo(s) · ${new Date(published.publishedAt).toLocaleString('pt-BR')}`
      : 'nada publicado';

    const gameName = document.createElement('span');
    gameName.className = 'game';
    gameName.textContent = game.name;
    const metaLabel = document.createElement('span');
    metaLabel.className = 'meta';
    metaLabel.textContent = meta;

    const picker = document.createElement('label');
    picker.className = 'file-picker';
    const pickerAction = document.createElement('span');
    pickerAction.className = 'file-pick-action';
    pickerAction.textContent = 'Escolher arquivo ZIP';
    const fileName = document.createElement('span');
    fileName.className = 'file-name';
    fileName.setAttribute('aria-live', 'polite');
    fileName.textContent = 'Toque aqui para escolher um ZIP (máx. 25 MB)';
    const fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.accept = '.zip,application/zip,application/x-zip-compressed';
    fileInput.setAttribute('aria-label', `Escolher arquivo ZIP para ${game.name}`);
    picker.append(pickerAction, fileName, fileInput);

    const publishButton = document.createElement('button');
    publishButton.className = 'btn small publish-button';
    publishButton.type = 'button';
    publishButton.textContent = published ? 'Publicar substituição' : 'Publicar';
    publishButton.disabled = true;
    publishButton.addEventListener('click', () => publishPayload(entry.id, game.id, fileInput, publishButton));

    const removeButton = document.createElement('button');
    removeButton.className = 'btn small danger';
    removeButton.type = 'button';
    removeButton.textContent = 'remover';
    removeButton.disabled = !published;
    removeButton.addEventListener('click', () => unpublishPayload(entry.id, game.id));

    fileInput.addEventListener('change', () => {
      const file = fileInput.files && fileInput.files[0];
      fileName.textContent = file ? `${file.name} · ${formatFileSize(file.size)}` : 'Toque aqui para escolher um ZIP (máx. 25 MB)';
      publishButton.disabled = !file;
    });

    row.append(gameName, metaLabel, picker, publishButton, removeButton);
    container.appendChild(row);
  }
}

function formatFileSize(bytes) {
  return bytes < 1024 * 1024
    ? `${Math.max(1, Math.round(bytes / 1024))} KB`
    : `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

async function publishPayload(functionId, gameId, fileInput, publishButton) {
  const file = fileInput.files && fileInput.files[0];
  if (!file) {
    toast('escolha o arquivo ZIP antes de publicar');
    return;
  }
  if (!file.name.toLowerCase().endsWith('.zip')) {
    toast('selecione um arquivo com extensão .zip');
    return;
  }
  if (file.size > 25 * 1024 * 1024) {
    toast('ZIP acima de 25 MB');
    return;
  }
  try {
    publishButton.disabled = true;
    publishButton.textContent = 'Publicando…';
    toast('publicando…');
    const buffer = await file.arrayBuffer();
    const result = await api(`/api/admin/functions/${functionId}/files/${gameId}`, {
      method: 'POST',
      headers: { 'content-type': 'application/zip' },
      body: buffer
    });
    toast(`${result.files.length} arquivo(s) publicados em ${functionId}/${gameId}`);
    fileInput.value = '';
    await loadState();
  } catch (error) {
    publishButton.disabled = false;
    publishButton.textContent = 'Tentar novamente';
    toast(error.message);
  }
}

async function unpublishPayload(functionId, gameId) {
  if (!confirm(`Remover o payload de ${functionId}/${gameId}? O app deixa de receber essa versão.`)) return;
  try {
    await api(`/api/admin/functions/${functionId}/files/${gameId}`, { method: 'DELETE' });
    await loadState();
    toast('payload removido');
  } catch (error) {
    toast(error.message);
  }
}

async function saveFunction(node, functionId) {
  const games = $$('[data-field="games"] input:checked', node).map((input) => input.value);
  const names = $('[data-field="locateNames"]', node).value
    .split(',').map((entry) => entry.trim()).filter(Boolean);
  const roots = $('[data-field="locateRoots"]', node).value
    .split(',').map((entry) => entry.trim()).filter(Boolean);

  const body = {
    id: functionId,
    name: $('[data-field="name"]', node).value.trim(),
    subtitle: $('[data-field="subtitle"]', node).value.trim(),
    groupId: $('[data-field="groupId"]', node).value,
    status: $('[data-field="status"]', node).value,
    games,
    locate: {
      mode: $('[data-field="locateMode"]', node).value,
      names,
      roots,
      maxMatches: Number($('[data-field="maxMatches"]', node).value) || 8
    }
  };
  try {
    await api('/api/admin/functions', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body)
    });
    await loadState();
    toast(`${functionId} salvo`);
  } catch (error) {
    toast(error.message);
  }
}

async function deleteFunction(functionId, name) {
  if (!confirm(`Excluir ${functionId} (${name}) e todos os payloads publicados?`)) return;
  try {
    await api(`/api/admin/functions/${functionId}`, { method: 'DELETE' });
    await loadState();
    toast('função excluída');
  } catch (error) {
    toast(error.message);
  }
}

async function createFunction() {
  const id = prompt('ID interno da função (formato 0xNNNN):', '0x1006');
  if (!id) return;
  const name = prompt('Nome exibido na lista:', 'NOVA FUNÇÃO');
  if (!name) return;
  try {
    await api('/api/admin/functions', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        id: id.trim(),
        name: name.trim(),
        subtitle: '',
        groupId: state.db.groups[0].id,
        status: 'active',
        games: state.db.games.map((game) => game.id),
        locate: { mode: 'path-or-name', names: [], roots: [], maxMatches: 8 }
      })
    });
    await loadState();
    toast('função criada — publique um ZIP para ela aparecer no catálogo');
  } catch (error) {
    toast(error.message);
  }
}

function renderAudit() {
  const list = $('#audit');
  list.innerHTML = '';
  for (const entry of state.db.audit || []) {
    const item = document.createElement('li');
    item.innerHTML = `${new Date(entry.at).toLocaleString('pt-BR')} · <code>${escapeAttribute(entry.action)}</code> ${escapeAttribute(entry.detail || '')}`;
    list.appendChild(item);
  }
}

function escapeAttribute(value) {
  return String(value == null ? '' : value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

async function connect() {
  const token = $('#token').value.trim();
  if (!token) {
    toast('informe o token');
    return;
  }
  state.token = token;
  localStorage.setItem('ffpatch-token', token);
  try {
    await loadState();
    toast('conectado');
  } catch (error) {
    toast(error.message);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  $('#token').value = state.token;
  $('#save-token').addEventListener('click', connect);
  $('#token').addEventListener('keydown', (event) => {
    if (event.key === 'Enter') connect();
  });
  $('#new-function').addEventListener('click', createFunction);
  $('#save-games').addEventListener('click', saveGames);
  $('#copy-catalog').addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText($('#catalog-url').value);
      toast('URL copiada');
    } catch {
      toast('copie manualmente');
    }
  });
  if (state.token) {
    loadState().catch((error) => toast(error.message));
  }
});
