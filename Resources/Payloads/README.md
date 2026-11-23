# Payloads

Cada subdiretório aqui é uma **função**: `<payload>/<gameID>/<caminho relativo ao container>`.
O motor copia os bytes 1:1 e guarda backup verificado por SHA-256.

- Guia completo: `docs/PAYLOADS.md`
- Manifest que amarra ids, nomes, grupos e jogos: `manifest.json`
- Os arquivos atuais (`Documents/ffpatch/*.cfg` e `*.json`) são marcadores do
  pipeline; troque pelo mod real mantendo o caminho relativo.