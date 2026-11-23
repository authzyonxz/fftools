# Payloads crus — guia de conteúdo

O motor não tem formato de pacote. O diretório da função **é** o container:
cada arquivo é copiado byte a byte para o mesmo caminho relativo dentro do
container do jogo escolhido.

## Nomenclatura

```
Resources/Payloads/
├── manifest.json
├── <payloadDirectory>/
│   └── <gameID>/
│       └── <caminho relativo ao container>
```

Exemplo real (HS ALTO no Free Fire Normal):

```
Resources/Payloads/hs_alto/freefireth/Documents/ffpatch/hs_alto.cfg
        ↓ apply("0x1001", "freefireth")
/var/mobile/Containers/Data/Application/<uuid>/Documents/ffpatch/hs_alto.cfg
```

O `gameID` casa com o campo `id` de `manifest.json`; o `bundle` do jogo é o que
resolve o container. `payloadDirectory` é o campo `payload` da função (se
ausente, usa o próprio id).

## Regras do motor (o que ele recusa)

- caminho absoluto, `..`, componente vazio → `FFErrorPathEscapesContainer`
- qualquer componente que seja symlink → `FFErrorSymlinkRefused`
- alvo que já é diretório → `FFErrorTargetIsDirectory`
- dois arquivos do payload caindo no mesmo alvo → `FFErrorDuplicateTarget`
- arquivo de payload vazio → `FFErrorInvalidPayload`
- payload ausente para o jogo → `FFErrorPayloadMissing`

Symlinks dentro do payload são ignorados na enumeração (não copiados).

## Descoberta do alvo: caminho x nome

Cada função declara no manifest como o payload encontra o alvo dentro do container:

```json
"locate": { "mode": "path-or-name", "names": ["global-metadata.dat"], "roots": ["Documents"], "maxMatches": 8 }
```

- `path` — o caminho relativo do payload é o caminho exato no container (cria se faltar).
- `name` — o app varre o container, acha todo arquivo com esse nome e substitui
  todos; se não achar nenhum, retorna erro `FFErrorTargetNotFound` com o total de
  entradas varridas.
- `path-or-name` — tenta o caminho exato; se o arquivo ainda não existe, varre por
  nome e substitui os matches; se não achar nada, cria o caminho declarado (é o
  que mantém os payloads-marcador funcionando).

Regras da varredura: BFS a partir da raiz do container (ou de `locate.roots`),
pula `Library/Caches`, `tmp`, `SplashBoard`, `Saved Application State`, `Logs`,
profundidade 8, teto de 400.000 entradas, até `maxMatches` alvos, nome sem
diferenciar maiúscula, symlink nunca alvo. `names[i]` corresponde ao i-ésimo
arquivo do payload (ordem alfabética); sem `names`, vale o nome do próprio arquivo.

Se o alvo estiver no `.app` e não no container de dados, use `"root": "bundle"`
no jogo — a varredura acontece no bundle container.
## Como trocar os marcadores pelo mod real

1. Onde o mod mora: o arquivo original do container que precisa ser
   substituído (ex.: um `.dat`, `.cfg`, `.json`, `.plist` ou binário qualquer).
2. Descubra o caminho **relativo ao container** dele. No jogo instalado:
   `/var/mobile/Containers/Data/Application/<uuid>/` é a raiz — o que vem depois
   é o caminho relativo (ex.: `Documents/algum/arquivo.bin`).
3. Coloque o arquivo do mod no payload correspondente:

```bash
# HS ALTO, Free Fire Normal
mkdir -p Resources/Payloads/hs_alto/freefireth/Documents/algum
cp mod_hs_alto.bin Resources/Payloads/hs_alto/freefireth/Documents/algum/arquivo.bin

# mesmo mod para o MAX
mkdir -p Resources/Payloads/hs_alto/freefiremax/Documents/algum
cp mod_hs_alto.bin Resources/Payloads/hs_alto/freefiremax/Documents/algum/arquivo.bin
```

4. Rebuild (`Scripts/build_ipa.sh`). Os arquivos-marcador `.cfg`/`.json` podem
   ficar ou sair — são inofensivos, mas se o mod não os usa, remova para a
   injeção tocar só o que interessa.

Um payload pode ter **vários arquivos** e **subdiretórios**: o motor aplica
todos na mesma transação, com um único rollback.

## Adicionar uma função nova

`manifest.json`:

```json
{
  "id": "0x1006",
  "name": "NO RECOIL",
  "subtitle": "Sem recuo na mira.",
  "payload": "no_recoil"
}
```

Depois crie `Resources/Payloads/no_recoil/<gameID>/<caminho>`.
O ID aparece no alerta de STATUS (`ID 0x1006 · NO RECOIL …`) e nos recibos.

## Grupos exclusivos

`"exclusive": true` no grupo faz o app restaurar as irmãs antes de aplicar a nova
(posição de HS é mutuamente exclusiva). O holograma não é exclusivo — pode ficar
ligado junto com um HS.

## Root `bundle`

Se o alvo do mod não é o container de dados e sim o `.app` instalado, troque no
manifest do jogo:

```json
{ "id": "freefireth", "bundle": "com.dts.freefireth", "root": "bundle" }
```

O `FFContainerStore` resolve o bundle container (MCM classe 1 + varredura de
`/var/containers/Bundle/Application`) e o caminho relativo passa a contar a
partir do `.app`. Depende do backend enxergar o bundle container — em
`bad_query` (26.0–26.6.1) esse caminho é limitado; o padrão do repo é `data`.

## Voltar tudo ao original

Aba **Perfil → RESTAURAR ORIGINAIS** (ou desligar cada toggle). O restore usa os
bytes guardados em `Library/Application Support/FFPatch/Transactions/...`;
se o jogo foi reinstalado, o fingerprint do container muda e o motor recusa
escrever no container novo em vez de arriscar estado inconsistente.
