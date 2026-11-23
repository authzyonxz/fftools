# FFPatch Catalogue

Site de catálogo do FFPatch: publica as funções, guarda os payloads cifrados
(FPP1) e serve o JSON que o app lê. Node >= 18, **zero dependências**.

## Rodar

```bash
export ADMIN_TOKEN="token-forte-do-painel"          # >= 8 caracteres
export MASTER_SECRET="segredo-de-32-bytes-compartilhado"  # >= 16, igual ao do app
export PUBLIC_URL="https://keyauthv2.org/3106"     # URL pública base, sem barra final
export HOST=127.0.0.1                              # não exponha a porta Node
export PORT=8787
export DATA_DIR=./data                              # db.json + packs/

node server.js
node scripts/selftest.js        # teste E2E: upload, FPP1, HMAC, status, auth
```

Painel público: `https://keyauthv2.org/3106/` — informe o `ADMIN_TOKEN` e clique em entrar.
Catálogo do app: `https://keyauthv2.org/3106/api/catalog`.

## Deploy

Qualquer host que rode Node 18 (VPS, Render, Railway, Fly, Dockerinho):

1. copie a pasta `ffpatch-site` para o servidor;
2. defina `ADMIN_TOKEN`, `MASTER_SECRET`, `PUBLIC_URL`, `DATA_DIR`;
3. `node server.js` (ou systemd/pm2);
4. ponha HTTPS na frente; no Nginx, use `location = /3106 { return 308 /3106/; }`
   e `location ^~ /3106/ { proxy_pass http://127.0.0.1:8787/; }` para remover o prefixo;
5. gere o `Catalog.plist` do app com `python Scripts/protect_config.py --url https://keyauthv2.org/3106 --secret-env MASTER_SECRET`
   e forneça o segredo pelo ambiente do build, nunca por um commit.

`DATA_DIR` guarda `db.json` e `packs/<função>/<jogo>/<fileId>.fpp`. Backup =
copiar essa pasta.

## Painel

- **funções**: nome, subtítulo, grupo, status (`ativo`, `manutenção`,
  `desativado`), jogos (`Free Fire Normal` / `Free Fire Max`), `locate`
  (`path`, `name`, `path-or-name`, nomes, raízes, `maxMatches`).
- **payload**: upload de ZIP com a árvore relativa ao container. Substituir =
  mesma função + mesmo jogo; remover = botão *remover*.
- **jogos**: bundle ID, nome e root (`data` ou `bundle`).
- **auditoria**: toda ação registrada com hora.

ZIP esperado (caminho relativo dentro do container do jogo):

```
Documents/ffpatch/hs_alto.cfg
Documents/ffpatch/hs_alto.json
```

O servidor valida o ZIP (sem `..`, sem path absoluto, sem zip bounce), cifra
cada arquivo com FPP1, calcula SHA-256, faz round-trip de verificação e só então
publica. Função sem payload não aparece no catálogo.

## API

Pública:

| rota | retorno |
| --- | --- |
| `GET /api/catalog` | `{schema, version, updatedAt, games[], groups[].functions[] com assets[]}` |
| `GET /f/<fileId>.fpp` | arquivo de payload cifrado (FPP1) |
| `GET /api/health` | `{ok, version, functions}` |

Admin (header `x-admin-token: <ADMIN_TOKEN>`):

| rota | ação |
| --- | --- |
| `GET /api/admin/state` | banco completo + URL do catálogo |
| `POST /api/admin/functions` | cria/atualiza função |
| `DELETE /api/admin/functions/:id` | exclui função + packs |
| `POST /api/admin/functions/:id/status` | `{status: active\|maintenance\|disabled}` |
| `POST /api/admin/functions/:id/games` | `{games: ["freefireth", ...]}` |
| `POST /api/admin/functions/:id/locate` | `{mode, names, roots, maxMatches}` |
| `POST /api/admin/functions/:id/files/:gameId` | corpo = ZIP bruto (application/zip) |
| `DELETE /api/admin/functions/:id/files/:gameId` | despublica |
| `POST /api/admin/games` | `{games:[{id,name,bundle,root,icon}]}` |
| `GET /api/admin/audit` | últimas 400 ações |

## FPP1

```
magic "FPP1" | IV(16) | HMAC-SHA256(32) | ciphertext AES-256-CBC/PKCS7

key_enc = SHA256(secret | "|" | "enc" | "|" | functionID | "|" | gameID)
key_mac = SHA256(secret | "|" | "mac" | "|" | functionID | "|" | gameID)
hmac    = HMAC-SHA256(key_mac, IV | ciphertext)
```

O app (`Sources/FFCrypto.m`) decodifica exatamente esse layout; o selftest e o
cross-check em Python (`docs/VERIFICACAO.md`) provam o formato.

## Segurança

- `ADMIN_TOKEN` e `MASTER_SECRET` só por variável de ambiente; o servidor
  **recusa subir** sem eles.
- Token do painel comparado em tempo constante; toda rota admin exige header.
- Upload limitado (25 MB), ZIP validado, nada de path traversal.
- Rate-limit não implementado de propósito: catálogo público, admin protegido
  por token — ponha o painel atrás de HTTPS e, se quiser, de um proxy com IP
  allowlist.

## Selftest

```bash
node scripts/selftest.js
```

Sobe o servidor numa porta aleatória com `DATA_DIR` temporário, publica um ZIP,
lê o catálogo, baixa e decifra os packs, testa HMAC com segredo errado, muda
status, muda jogos, valida 401 sem token e despublica. Sai 0 só se tudo bater.
