# FFPatch — motor de patch por container (Free Fire / Free Fire MAX)

App iOS em **Objective-C puro** que aplica arquivos crus dentro do container de
`com.dts.freefireth` e `com.dts.freefiremax`: sem pacote `.3105`, sem regra
proprietária — o payload **espelha o container** e o motor copia byte a byte,
com backup verificado por SHA-256 e restauração exata.

A lógica inteira roda dentro de **`ffpatch.dylib`**. O binário principal da IPA é
um stub `MH_EXECUTE` de 60 linhas (`launcher/main.c`) que abre a dylib e chama
`FFAppMain()`. Sem Swift, sem SwiftUI, sem Combine no target.

Base herdada do projeto [3106](https://github.com/QuinnTang74/3106) (fork do
[3105](https://github.com/YangJiiii/3105), ambos GPL-3.0): as camadas
`mcm_bridge`, `bad_query`, `worse_query`, a cadeia `kexploit_opa334 +
sandbox_escape` e a política de versões suportadas. O motor de patch é o
`PatchTransaction.swift` do 3106 **portado para ObjC** e refeito para payload cru.
Atribuição completa em [NOTICE.md](NOTICE.md).

---

## 1. Estrutura

```
fftools/
├── Sources/
│   ├── FFCore.h/.m            log, SHA-256, IO atômico, higiene de path, plist
│   ├── FFSandbox.h/.m         roteamento kernel / bad_query / worse_query + grants
│   ├── FFContainerStore.h/.m  bundle id → caminho do container (MCM + índice + metadata)
│   ├── FFManifest.h/.m        manifest JSON, jogos, grupos, funções, payloads
│   ├── FFPatchEngine.h/.m     transação apply / restore com journal e recibos
│   ├── FFLicense.h/.m         dados da aba PERFIL (chave, duração, package, build)
│   ├── FFAppDelegate.h/.m     UIWindow + tab bar (Início / Perfil)
│   ├── entry.m                FFAppMain() exportado pela dylib
│   ├── UI/
│   │   ├── FFTheme              paleta e fontes do layout de referência
│   │   ├── FFWidgets            cards, linhas com toggle, alerta STATUS, badge
│   │   ├── FFHomeViewController tela FUNÇÕES
│   │   └── FFProfileViewController tela PERFIL
│   └── Vendor/                C/ObjC copiado do 3106 (GPL-3.0)
├── launcher/main.c            stub MH_EXECUTE que dlopen'a a dylib
├── Resources/
│   ├── Info.plist, License.plist, FFPatch.entitlements
│   ├── Assets/                ícones FF Normal / FF Max (1x/2x/3x)
│   ├── Assets.xcassets/       AppIcon 1024 + tamanhos
│   └── Payloads/              manifest.json + payloads crus por função/jogo
├── Scripts/
│   ├── build_ipa.sh           build macOS (clang + xcrun) → IPA unsigned
│   ├── build_theos.sh         build via Theos (dylib + launcher)
│   └── make_icons.py          gera todos os PNG a partir dos dois artworks
├── Makefile                   alvo Theos da dylib
├── launcher/Makefile          alvo Theos do stub
└── .github/workflows/build.yml  CI macOS → artifact IPA
```

## 2. Como o patch funciona

Unidade = **função** (`0x1001` HS ALTO …) × **jogo** (`freefireth` / `freefiremax`).

```
apply(função, jogo)
 1. resolve o container do bundle id do jogo
     1.1 índice do worse_query (iOS 26.7+/27)
     1.2 container_query_* do MobileContainerManager
     1.3 varredura dos metadata.plist em /var/mobile/Containers/Data/Application
 2. descobre o alvo de cada arquivo do payload (locate)
     2.1 path         → caminho exato espelhado
     2.2 name         → VARRE o container e acha todo arquivo com aquele nome
     2.3 path-or-name → caminho exato se já existe; senão varre; senão cria
 3. valida cada alvo (sem "..", sem symlink, não é diretório, sem duplicata)
 4. backup de cada alvo existente  → <transação>/<idx>.original  (SHA-256 gravado)
 5. grava journal.plist com status "prepared"
 6. cria diretórios ausentes (registra quais criou)
 7. para cada arquivo: grant no diretório pai → arquivo temporário → fsync →
    rename → confere SHA-256 do que caiu no disco
 8. journal → "applied", grava recibo

falha em qualquer passo → rollback: bytes originais voltam, arquivos novos
somem, diretórios criados são removidos se vazios, journal → "rolledBack".
```

### 2.1 Descoberta do alvo — varredura por nome

É o fluxo que você descreveu: ativa a função → o app entra no container do jogo,
varre, encontra o arquivo pelo nome e substitui.

`locate.mode` no manifest decide:

| modo | comportamento | quando usar |
|---|---|---|
| `path` (padrão) | caminho relativo exato do payload | você sabe o caminho e ele não muda |
| `name` | varre o container e substitui **todos** os arquivos com o nome; zero matches = erro | caminho muda entre versões/builds, só o nome importa |
| `path-or-name` | tenta o caminho exato; se não existe, varre por nome e substitui os matches; se nada casa, cria o caminho declarado | padrão seguro: funciona com arquivo que já existe e com marcador |

A varredura:

- BFS a partir da raiz do container (ou de `locate.roots`, ex. `["Documents","Library"]`);
- pula `Library/Caches`, `tmp`, `SplashBoard`, `Saved Application State`, `Logs`,
  `com.apple.nsurlsessiond` — nome de arquivo de mod não vive em cache;
- profundidade máxima 8, teto de 400.000 entradas, no máximo `locate.maxMatches`
  (padrão 8) arquivos substituídos por arquivo de payload;
- comparação de nome sem diferenciar maiúscula/minúscula; symlink nunca é alvo;
- diretório negado → pede grant pro diretório e tenta a listagem de novo uma vez;
- relata no alerta quantas entradas foram varridas (`varredura: N entradas`) e
  grava tudo em `ffpatch.log`.

```json
{
  "id": "0x1001",
  "name": "HS ALTO",
  "payload": "hs_alto",
  "locate": {
    "mode": "path-or-name",
    "names": ["global-metadata.dat"],
    "roots": ["Documents", "Library"],
    "maxMatches": 8
  }
}
```

`names[i]` casa com o i-ésimo arquivo do payload (ordem alfabética); sem `names`,
usa o próprio nome do arquivo do payload. Se o alvo está no `.app` e não no
container de dados (caso de metadados Unity), troque o jogo para `"root": "bundle"`
— a varredura passa a acontecer no bundle container.

`restore(função, jogo)` confere o fingerprint do container e o digest de cada
backup, tira um snapshot dos bytes atuais (para que um restore que falhe no meio
não perca nada), devolve os originais, apaga os arquivos que não existiam antes
e limpa diretórios vazios.

Tudo em `Library/Application Support/FFPatch/`:

```
Transactions/<função>__<jogo>/<uuid>/journal.plist
                                   <idx>.original
Receipts/<função>__<jogo>.plist
ffpatch.log
```

## 3. Payload cru (o que substitui o pacote `.3105`)

O diretório da função **é** o container. Nada de JSON de regras no payload:

```
Resources/Payloads/hs_alto/freefireth/Documents/ffpatch/hs_alto.cfg
                                ↓
<container de com.dts.freefireth>/Documents/ffpatch/hs_alto.cfg
```

O que estiver em `Payloads/<payload>/<jogo>/` é copiado 1:1, com subdiretórios,
para o mesmo caminho relativo dentro do container. Guia completo em
[docs/PAYLOADS.md](docs/PAYLOADS.md).

`Resources/Payloads/manifest.json` declara jogos, grupos e funções:

```json
{
  "games": [
    { "id": "freefireth",  "name": "Free Fire Normal", "bundle": "com.dts.freefireth",
      "icon": "ic_game_normal", "root": "data" },
    { "id": "freefiremax", "name": "Free Fire Max",    "bundle": "com.dts.freefiremax",
      "icon": "ic_game_max",    "root": "data" }
  ],
  "groups": [
    { "id": "aimbot", "title": "Funções de Aimbot", "exclusive": true,
      "functions": [
        { "id": "0x1001", "name": "HS ALTO", "subtitle": "HS Acima da Cabeça do Inimigo.",
          "payload": "hs_alto" }
      ] }
  ]
}
```

`exclusive: true` = só uma injeção do grupo por vez (ligar uma desfaz a irmã
aplicada). `root` aceita `data` (container de dados, padrão) e `bundle` (dentro
do `.app` instalado, alcançável pelo backends que enxergam o bundle container).

### IDs internos das funções

| ID | Função | Grupo | Payload |
| --- | --- | --- | --- |
| `0x1001` | HS ALTO | aimbot | `hs_alto` |
| `0x1002` | HS ALTO + PESCOÇO | aimbot | `hs_alto_pescoco` |
| `0x1003` | HS PESCOÇO | aimbot | `hs_pescoco` |
| `0x1004` | HS CAVEIRA | aimbot | `hs_caveira` |
| `0x1005` | HS PEITO | aimbot | `hs_peito` |
| `0x2001` | HOLOGRAMA ARMAS | hologram | `holograma_armas` |

Os payloads que acompanham o repo são **marcadores** (`Documents/ffpatch/*.cfg`
+ `.json`) para o pipeline funcionar ponta a ponta hoje. Troque o conteúdo pelo
arquivo real do container mantendo o caminho — o motor não interpreta bytes.

## 4. UI

**Aba Início (casa)** — layout do print de referência:
título `FUNÇÕES`, dois cards de jogo (borda branca 2 px no selecionado),
seções `FUNÇÕES DE AIMBOT` / `FUNÇÕES DE HOLOGRAMA`, linhas com título,
subtítulo e `UISwitch`. Cada toggle aplica/restaura; enquanto roda, overlay com
spinner; ao terminar, alerta estilo Apple:

```
        STATUS
        ✓
 INJETADO COM SUCESSO
 ID 0x1001 · HS ALTO · Free Fire Normal · 2 arquivos
 ─────────────────────────────────────────────
                 FECHAR
```

Falha → mesmo alerta, `FALHA NA OPERAÇÃO` + motivo real (app ausente, payload
ausente, sem permissão de sandbox, SHA-256 divergente, etc.).

**Aba Perfil (pessoa)** — chave, duração, status, package, versões compatíveis,
build, modelo do aparelho, iOS/build do sistema, backend ativo, acesso ao
container, injeções ativas, caminho do log, botão **RESTAURAR ORIGINAIS** e
**EXPORTAR DIAGNÓSTICO**.

## 5. Backends por versão

| Faixa | Backend | O que o app faz |
| --- | --- | --- |
| iOS 17.0–17.7.x | `kernel` | botão DESBLOQUEAR → `kexploit_opa334` + `sandbox_escape` (10–30 s, aparelho pode congelar) |
| iOS 18.0–18.7.1 | `kernel` | idem, **recusado em A10 + iOS 17** (trava) |
| iOS 26.0–26.6.1 | `bad_query` | grant por diretório, ativação silenciosa no boot |
| iOS 26.7–26.7.2 | `worse_query` | precisa de App Group no profile (AltStore/SideStore/Sideloadly ou App ID explícito) |
| iOS 27.0–27.2 | `worse_query` | idem |
| iOS 27.3 beta 1 (`24C5037i`) | `worse_query` | build-gated: qualquer outra build de 27.3 é recusada |
| iOS 18.7.2+ / 27.3 beta 2+ | — | recusa explícita com o motivo (Apple patcheou CVE-2025-43510/43520 e a técnica do worse_query) |

## 6. Build

Duas rotas, as duas terminam no mesmo artefato: `build/FFPatch-<versão>-unsigned.ipa`.

### 6.1 Theos (Linux / WSL / macOS / aparelho)

Theos compila a dylib e o stub. **Ele não gera IPA sozinho** (`make package` gera
`.deb`, que não serve aqui) — por isso o projeto traz o empacotador:

```bash
export THEOS=~/theos
chmod +x Scripts/*.sh

./Scripts/build_theos.sh
# 1. make  → ffpatch.dylib          (a app inteira)
# 2. make  → ffpatch_launcher       (stub MH_EXECUTE)
# 3. Scripts/package_ipa_theos.sh   → monta Payload/FFPatch.app e zipa a IPA

# só compilar, sem IPA:
./Scripts/build_theos.sh --no-ipa
```

Saída: `build/Payload/FFPatch.app` + `build/FFPatch-1.0.0-unsigned.ipa`.
Se você já tem os artefatos, roda só `Scripts/package_ipa_theos.sh`
(aceita `FFPATCH_DYLIB=...` / `FFPATCH_LAUNCHER=...`).

### 6.2 macOS com Xcode CLT (clang direto, sem Theos)

```bash
chmod +x Scripts/build_ipa.sh
./Scripts/build_ipa.sh
# opcionais:
#   CODESIGN_IDENTITY="Apple Development: voce (TEAMID)" ./Scripts/build_ipa.sh
#   OUTPUT_VERSION=1.0.1 ./Scripts/build_ipa.sh
```

### 6.3 Sem Mac nenhum

Push no repo e baixe o artifact do workflow
`.github/workflows/build.yml` (runs-on `macos-14`, roda `build_ipa.sh`).

### 6.4 FAQ — "preciso da IPA do 3106/projeto original?"

**Não.** A IPA deste projeto é autocontida: `FFPatch.app` = stub `MH_EXECUTE` +
`Frameworks/ffpatch.dylib` + recursos. O backend de sandbox (`worse_query`,
`bad_query`, `kexploit_opa334`) está compilado **dentro** da dylib e o
entitlement de App Group vem da **assinatura**, não do binário de outro app.

Quando alguém "pega a IPA original e troca o binário pela dylib" é para herdar
**bundle id/entitlements** de outro app (truque MHA do 3105). Aqui isso não é
necessário: o bundle ID é nosso (`com.daddy.ffpatch`) e o grupo é criado pelo
signer (AltStore/SideStore/Sideloadly).

Se você *quiser* injetar em outro IPA (por exemplo dentro do próprio 3106, que
já tem os entitlements de container), a dylib serve como dylib mesmo: coloque em
`Frameworks/` do app hospedeiro e faça o binário dele carregar — nesse modo a UI
sobe sobre o app host. Para o fluxo normal deste projeto, não.

**Requisitos do Theos:** toolchain iOS + SDK (via Xcode, ou `theos` em Linux com
SDK baixado), `ARCHS=arm64`. Windows puro não roda Theos — use WSL2 ou a rota
6.3.

## 7. Instalar

1. Assine a IPA: **ESign** com certificado enterprise, ou **AltStore/SideStore/
   Sideloadly** com Apple ID.
2. Em iOS 26.7+ / 27.x o profile precisa carregar a capability **App Groups** —
   AltStore/SideStore criam automaticamente; certificado `.p12` + profile
   wildcard **não funciona** (o `worse_query` reporta "No App Group"). Em iOS
   17/18 e iOS 26.0–26.6.1 isso não é exigido.
3. Abra o app. Em iOS 17/18 toque **DESBLOQUEAR** uma vez e espere.
4. Escolha o card do jogo, ligue a função. Feche o Free Fire antes de aplicar —
   o jogo com arquivo aberto pode regravar ou travar a escrita.

## 8. Limites honestos

- **Não é jailbreak**: não instala bootstrap/daemon e não injeta código no jogo.
  Usa exploit de dispositivo (iOS 17/18) ou grants de sandbox (iOS 26/27), e
  pode tocar dados de app — nenhuma garantia universal contra detecção de
  integridade do próprio jogo.
- A cadeia de kernel pode **falhar ou reiniciar o app** numa tentativa — é
  esperado e documentado pelo backend que originou o código.
- O fingerprint do container muda se o jogo for reinstalado: nesse caso o
  restore pede reinstalação/manual em vez de escrever no container errado.
- Backup de "app inteiro" não existe: só os arquivos que cada função toca.
- 18.7.2+, 26.7.3+, 27.3 beta 2+ e além: **não suportado por design**.

## 9. Aviso

Software de pesquisa para o próprio aparelho. Rode só em dispositivo e conta
seus, com backup. Usar mod em partida online viola os termos do jogo e pode
resultar em ban — o dano é seu e o registro é seu.

## 10. Licença

FFPatch: GPL-3.0. Componentes de terceiros mantêm suas licenças — ver
[LICENSE](LICENSE) e [NOTICE.md](NOTICE.md).
