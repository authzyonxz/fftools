# Verificação — o que foi provado nesta máquina e o que não foi

Esta máquina é Windows, sem Xcode e sem SDK iOS. Tudo o que dava para provar
offline foi provado; o que depende de toolchain Apple está listado em
"Não verificado" com o comando exato para fechar a lacuna.

## Rodado e passando

| Checagem | Comando | Resultado |
| --- | --- | --- |
| Sintaxe/typos de todo o ObjC novo (12 arquivos) | `Scripts\syntax_check\check.cmd` | `EXIT=0`, nenhum erro |
| Avisos de seletor/tipo (`no visible @interface`, `no known class method`, `incompatible pointer`, block, operando) | mesma ferramenta, sem mascarar esses avisos | **0** ocorrências |
| `-Wall -Wextra` nos 12 arquivos | idem | **0** avisos |
| Sintaxe do stub `MH_EXECUTE` | `clang -fsyntax-only launcher/main.c` | `EXIT=0` |
| Plists (`Info.plist`, `License.plist`, `entitlements`) | `python Scripts/verify_project.py` | parseiam; bundle id e App Group conferem |
| `manifest.json` + `Contents.json` | idem | schema 1, ids `0xNNNN` únicos, bundles esperados |
| Payloads × manifest × jogos | idem | 6 funções × 2 jogos, 2 arquivos cada, sem path inseguro/symlink/vazio |
| Config locate (path / name / path-or-name) | python Scripts/verify_project.py | modo válido, names sem /, roots relativos |
| Ícones 1x/2x/3x e AppIcon 1024 | idem | dimensões exatas conferidas via Pillow |
| Mockups da UI | `python Scripts/make_mockup.py` | mesma paleta/métrica do `FFTheme.m` |

O harness de sintaxe usa stubs mínimos de Foundation/UIKit/POSIX/CommonCrypto em
`Scripts/syntax_check/stubs/`. Ele **não** substitui o build real: serve para
provar que o código parseia e que nenhum seletor digitado errado sobrou — foi
exatamente ele que pegou uma mensagem encadeada inválida no
`receiptPathForFunction:` durante o desenvolvimento.

## Não verificado (precisa de macOS com Xcode)

| Item | Por quê | Como fechar |
| --- | --- | --- |
| Link real dylib + frameworks | falta SDK iOS | `./Scripts/build_ipa.sh` num Mac |
| `ffpatch.dylib` embutida e `dlopen` do stub | idem | workflow `.github/workflows/build.yml` (macos-14) |
| Assinatura + App Group em aparelho | precisa conta/certificado | ESign / AltStore / Sidehold + aparelho |
| Runtime nos backends (kernel, bad_query, worse_query) | precisa aparelho suportado | aba Perfil → backend, e log em `Library/Application Support/FFPatch/ffpatch.log` |
| Código em `Sources/Vendor/` (kexploit, worse_query, offsets…) | cópia GPL do 3106, compilado e publicado lá | herdado: compila no build 3106; aqui entra no mesmo link |

## Números

```
Sources/*.m, Sources/UI/*.m        12 arquivos ObjC verificados
Sources/Vendor/                    20 arquivos C/ObjC herdados do 3106
launcher/main.c                    stub MH_EXECUTE
funções declaradas no manifest     6 (5 aimbot + 1 holograma), IDs 0x1001–0x2001
payloads                          12 árvores cruas (6 × 2 jogos)
ícones in-app                      FF Normal + FF Max em 1x/2x/3x
```

## Reproduzir

```bash
# qualquer SO com Python + Pillow
python Scripts/verify_project.py
python Scripts/make_mockup.py

# Windows, com LLVM/clang instalado (C:\Program Files\LLVM\bin\clang.exe)
Scripts\syntax_check\check.cmd

# macOS (fecha a lacuna de link/empacotamento)
./Scripts/build_ipa.sh
```
