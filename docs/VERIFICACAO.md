# Verificação — o que foi provado nesta máquina, e o que não foi

Sem Xcode e sem aparelho aqui. Tudo o que dava para provar offline foi provado;
a lista de lacunas diz exatamente o comando que fecha cada uma.

## Rodado e passando

| Checagem | Comando | Resultado |
| --- | --- | --- |
| Sintaxe/typos de todo o ObjC (15 arquivos) | `Scripts\syntax_check\check.cmd` | `EXIT=0`, nenhum erro |
| Seletor/tipo (`no visible @interface`, `no known class method`, block, ponteiro incompatível) | mesma ferramenta | **0** ocorrências |
| `-Wall -Wextra` nos 15 arquivos | idem | **0** avisos |
| Sintaxe do stub `MH_EXECUTE` | `clang -fsyntax-only launcher/main.c` | `EXIT=0` |
| Scripts bash (`build_ipa`, `build_theos`, `package_ipa_theos`) | `shellcheck v0.10 -S warning` | **0** issues |
| Selftest do site (E2E) | `node ffpatch-site/scripts/selftest.js` | catálogo, upload ZIP, FPP1, HMAC, SHA-256, status, games, auth 401, unpublish |
| FPP1 cross-check (Node ↔ Python independente) | `Scripts/…` (ver histórico) | derivação de chave, HMAC e AES batem byte a byte |
| Máscara de config (app ↔ script) | `Scripts/protect_config.py` + decode independente | URL e segredo voltam idênticos; campos em claro removidos |
| Plists (`Info`, `License`, `Catalog`, entitlements) | `python Scripts/verify_project.py` | parseiam; bundle id/executable/App Group conferem |
| IPA sem payload / sem README / sem ícone sobrando | idem | `Resources/Payloads` ausente; 2 ícones de jogo + 3 de springboard |
| Site sem dependências externas | idem | `package.json` sem `dependencies` |
| Mockups da UI | `python Scripts/make_mockup.py` | mesma paleta/métrica do `FFTheme.m` |

O harness de sintaxe usa stubs mínimos (Foundation/UIKit/POSIX/CommonCrypto/
URLSession) em `Scripts/syntax_check/stubs/`. Ele pega erro de sintaxe, seletor
inexistente e tipo incompatível; não substitui o linker da Apple.

## Não verificado (precisa de macOS com Xcode)

| Item | Por quê | Como fechar |
| --- | --- | --- |
| Link real dylib + frameworks + IOSurface | falta SDK iOS | `./Scripts/build_ipa.sh` num Mac |
| `dlopen` da dylib pelo stub, `UIApplicationMain` | idem | workflow `macos-26` ou Mac |
| Assinatura + App Group em aparelho | conta/certificado | ESign / AltStore / SideStore |
| Runtime dos backends (kernel, bad_query, worse_query) | aparelho suportado | aba Perfil + `Application Support/FFPatch/ffpatch.log` |
| Decifragem FPP1 pelo CommonCrypto no device | idem | primeira sincronização real: log `catalog: pronto` |
| Código em `Sources/Vendor/` | cópia GPL do 3106, compilado e publicado lá | herdado |

## Números atuais

```
Sources/*.m, Sources/UI/*.m     15 arquivos ObjC verificados
Sources/Vendor/                 20 arquivos C/ObjC herdados do 3106
launcher/main.c                 60 linhas, stub MH_EXECUTE
IPA                             stub + dylib + 4 plists + 2+3 PNGs (sem payload)
site                            Node >= 18, zero dependências, selftest E2E
packs                           FPP1 AES-256-CBC + HMAC-SHA256 + SHA-256
```

## Reproduzir

```bash
# app
python Scripts/verify_project.py
python Scripts/make_mockup.py
Scripts\syntax_check\check.cmd          # Windows + LLVM/clang
./Scripts/build_ipa.sh                  # macOS: fecha link + IPA

# site
cd ../ffpatch-site
node scripts/selftest.js
```

## Correções de build aplicadas (reportadas no teste em aparelho)

| # | Problema | Correção |
| --- | --- | --- |
| 1 | `FFHomeViewController.h` não encontrado | `-I Sources/UI` no `build_ipa.sh` |
| 2 | `size_t` desconhecido em `Vendor/krw.h` | `#include <stddef.h>` |
| 3 | runner `macos-14` aposentado | `runs-on: macos-26` |
| 4 | aviso de ciclo de retenção capturando `row` | captura `__weak` + `__strong` local |
| 5 | backend kernel exigia toque em DESBLOQUEAR | inicia sozinho no boot, sem UI |
| 6 | toggle ligado não ficava verde | `onTintColor = success` (verde preenchido) |
| 7 | erros em texto longo | `FFUserMessageForError()` com 1 linha em pt-BR |
