KEYAUTH EXTERNAL — DOCUMENTAÇÃO E INTEGRAÇÃO DE REFERÊNCIA
Base inspecionada em 27/11/2026: https://keyauthv2.org

Abra docs/API.html no navegador. A documentação é independente e funciona offline.

PACOTE FIXO
Nome: EXTERNAL
Slug: external1
ID público: 5d933aad-02da-4f37-a509-dfffee5600ed
ID numérico observado no banco: 2 (somente API legada; pode variar em outro ambiente)

CONTEÚDO
ios/              Cliente Objective-C, Keychain/Secure Enclave, verificação ES256,
                  tela UIKit e controlador que libera o conteúdo após validação.
cpp/              Codec AES-256-GCM compatível com /api/v1/command, OpenSSL 3.
objc-aes/         Adaptador Objective-C++ para o codec AES legado.
tests/            Testes de compatibilidade Node/C++, adulteração e JWT ES256.
docs/API.html     Contratos, erros reais, integração, limites e proteção no servidor.

O fluxo iOS usa /api/v2 e NÃO requer token administrativo wqd_.
O AES legado usa /api/v1/command e NÃO deve levar esse token dentro do IPA.
O token Logos enviado anteriormente NÃO é um token wqd_ e não é usado aqui.

O SDK é uma alternativa de integração à Logos. Não altera a biblioteca Logos,
não foi colocado no app de produção e não modifica seu temporizador.
Não execute dois coordenadores de licença simultaneamente.

REQUISITOS IOS
iOS 15+, ARC, UIKit, Foundation, Security, assinatura válida e aparelho com Secure Enclave.
Adicione os .h/.m de ios/ ao target. Leia ios/IntegrationExample.txt.
Não adicione tests/, cpp/ ou objc-aes/ ao target iOS normal.
O Keychain exige Bundle ID e entitlements compatíveis com a assinatura.
O código falha fechado se não puder usar o Secure Enclave; não simula proteção no simulador.

VALIDAÇÃO
Consulte VALIDATION.txt para os resultados e limites dos testes.
Não existe promessa de proteção absoluta contra hooks/patches em aparelho comprometido.
O servidor deve revalidar cada recurso protegido; /3106 ainda não faz isso.
