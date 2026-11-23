# Publicando funções — site + payload cru

A IPA não leva payload nenhum. Tudo é publicado no site (`work/ffpatch-site`),
que serve os arquivos cifrados em FPP1; o app baixa, decifra e aplica no
container do jogo.

## 1. Subir um payload

No painel (`/` → token → função → jogo → **substituir**), envie um ZIP onde a
árvore **é** o caminho relativo dentro do container:

```
Documents/ffpatch/hs_alto.cfg
Documents/ffpatch/hs_alto.json
```

Regras que o servidor valida antes de publicar:

- sem caminho absoluto, sem `..`, sem `__MACOSX`, sem entrada oculta;
- arquivo não vazio;
- o ZIP precisa abrir (stored ou deflate);
- o pack cifrado passa por round-trip de decifragem e SHA-256 antes de entrar
  no catálogo.

Tamanho máximo de upload: 25 MB (`MAX_UPLOAD_BYTES`).

## 2. Descobrir o caminho certo

O arquivo alvo mora em
`/var/mobile/Containers/Data/Application/<uuid>/` (container de dados) ou dentro
do `.app` instalado (bundle). O caminho relativo é o que vem depois da raiz.

Se você não sabe o caminho (muda entre versões/builds do jogo), use a varredura:

```json
"locate": { "mode": "name", "names": ["global-metadata.dat"], "maxMatches": 8 }
```

- `path`: o caminho do ZIP é exato e obrigatório (cria se faltar);
- `name`: o app varre o container e substitui **todos** os arquivos com esse
  nome; zero matches = erro `Arquivo não encontrado no jogo`;
- `path-or-name`: tenta o caminho exato; se não existe, varre; se não acha nada,
  cria o caminho declarado.

Regras da varredura: BFS na raiz do container (ou em `locate.roots`), pula
`Library/Caches`, `tmp`, `SplashBoard`, `Saved Application State`, `Logs`,
profundidade 8, teto de 400.000 entradas, até `maxMatches` alvos, nome sem
diferenciar maiúsculas, symlink nunca é alvo.

## 3. Escolher o jogo

Cada função tem a lista de jogos publicados:

- `freefireth` → `com.dts.freefireth` (Free Fire Normal)
- `freefiremax` → `com.dts.freefiremax` (Free Fire Max)

Publicar só no Normal: marque apenas `Free Fire Normal` no cartão da função.
A mesma função pode ter payloads diferentes por jogo (um ZIP por jogo). O app
mostra a linha só no card do jogo correspondente e aplica no bundle daquele jogo.

## 4. Manutenção, substituição e remoção

| Ação no painel | Efeito no app |
| --- | --- |
| status `ativo` | linha normal, toggle liberado |
| status `manutenção` | linha aparece como `EM MANUTENÇÃO`, toggle desligado |
| status `desativado` | função some do catálogo |
| **substituir** (upload novo ZIP) | próxima sincronização baixa a versão nova (SHA-256 muda, cache é refeito) |
| **remover** payload de um jogo | função some daquele jogo; `apply` em andamento continua válido |
| excluir função | some do catálogo; payloads apagados do servidor |

O app tem **SINCRONIZAR CATÁLOGO** no Perfil; sem tocar, ele já sincroniza no
boot e usa cache local se estiver offline.

## 5. Bundle `bundle` (alvo dentro do `.app`)

Se o alvo do mod está dentro do `.app` instalado (caso de metadados de engine),
marque `root = bundle` no jogo (painel → jogos). O app resolve o bundle
container e a varredura acontece lá dentro. Depende do backend enxergar bundle
container — em `bad_query` (iOS 26.0–26.6.1) isso é limitado.

## 6. Onde o app guarda o que baixou

```
Application Support/FFPatch/Catalog/<função>/<jogo>/<caminho>
Application Support/FFPatch/Catalog/catalog.json          (cache do catálogo)
Application Support/FFPatch/Transactions/...              (backups do apply)
```

Nada disso fica no bundle do app (o que está na IPA é imutável e auditável com
`unzip -l`). A cópia decifrada existe só para o apply/restore; **RESTAURAR
ORIGINAIS** devolve os bytes do container e o backup continua em `Transactions/`.

## 7. Problemas comuns

| sintoma no app | causa | correção |
| --- | --- | --- |
| `Nenhuma função publicada` | nenhuma função com payload publicado | publique um ZIP e sincronize |
| `Arquivo não encontrado no jogo` | `locate.mode = name` não achou o nome | ajuste `names`/`roots` no painel |
| `Verificação falhou` | `MASTER_SECRET` do app diferente do servidor | rode `protect_config.py` com o mesmo segredo e rebuild |
| `Sem permissão de acesso` | backend não ativo (App Group ausente, device não suportado) | veja a aba Perfil (backend/versão) |
| linha em `EM MANUTENÇÃO` | status publicado assim | mude para `ativo` no painel |
