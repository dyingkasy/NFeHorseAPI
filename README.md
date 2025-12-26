# NFeHorseAPI

API em Delphi (Horse) para consulta de distribuicao de DF-e (NFe) via ACBr.

## Como executar

- Compilar com Delphi (RAD Studio) no target Win32.
- Executar o binario gerado.
- Porta padrao: `9000`.

Ao iniciar, o console exibe: `NFeHorseAPI iniciando na porta 9000...`.

## Endpoints

### GET /ping

Resposta simples para health check.

Resposta:
```
pong
```

### POST /nfe/zip/:cnpj

Consulta distribuicao por UltNSU e retorna um ZIP agregado com os `docZip`.
Tambem grava os ZIPs em disco e persiste o `ultnsu`.

Headers:
- `Content-Type: application/json`

Body (JSON):
- `cnpj` (string, opcional se vier na URL)
- `certSerie` (string, obrigatorio)
- `certSenha` (string, obrigatorio)
- `ambiente` (string, opcional: `producao` ou `homologacao`; default `producao`)
- `ultNSU` (string, opcional; se vazio, usa o salvo em disco ou `0`)
- `codUF` (string ou numero, obrigatorio)

Exemplo:
```bash
curl -X POST "http://localhost:9000/nfe/zip/12345678000199" \
  -H "Content-Type: application/json" \
  -d "{\"certSerie\":\"0000000000000000\",\"certSenha\":\"SENHA\",\"ambiente\":\"producao\",\"ultNSU\":\"0\",\"codUF\":35}"
```

Respostas:
- `200 application/zip`: ZIP agregado com os `docZip` retornados pela SEFAZ.
- `204`: nenhum documento localizado (cStat 137).
- `400 application/json`: parametros obrigatorios ausentes (ex.: `cnpj`, `codUF`).
- `429 application/json`: consumo indevido / bloqueio temporario (cStat 656).
- `502 application/json`: erro retornado pela SEFAZ (cStat > 0 e <> -1).
- `500 application/json`: erro interno.

Exemplo de erro:
```json
{
  "sucesso": false,
  "mensagem": "Erro na SEFAZ: 999 - Motivo",
  "cStat": 999,
  "xMotivo": "Motivo"
}
```

## Persistencia em disco

- ZIPs: `Documents\\NFeHorseAPI\\Download\\yyyymm\\Down\\<CNPJ>\\NSU_SCHEMA.zip`
- UltNSU: `Documents\\NFeHorseAPI\\State\\<CNPJ>\\ultnsu.txt`

## Dependencias

- Horse
- ACBr (NFe)
- FireDAC (apenas para `uDB.pas`, nao usada nas rotas atuais)

## Observacoes

- O certificado e informado por numero de serie e senha no JSON.
- O ambiente usa `homologacao` ou `producao`.

## Certificado e ACBr (configuracao atual)

O projeto usa o ACBrNFe diretamente no codigo (`uNFeDistribuicaoService.pas`).
Nao ha arquivo `.ini` ou config externa: o certificado e o ambiente sao
informados via JSON em cada chamada.

### Certificado

- A API espera `certSerie` com o numero de serie do certificado instalado no Windows.
- A senha do certificado vai em `certSenha`.
- Se o certificado nao estiver instalado no repositorio do Windows, a chamada vai falhar.

### Schemas da NFe

O ACBr usa `PathSchemas` apontando para a pasta `Schemas\\NFe` ao lado do executavel:

```
<pasta-do-exe>\\Schemas\\NFe
```

Garanta que os schemas da NFe estejam nesse caminho no deploy.

### Ambiente

- `ambiente = producao` -> `taProducao`
- `ambiente = homologacao` (ou `taHomologacao`) -> `taHomologacao`

### Observacoes do ACBr

- SSL/HTTP: `WinCrypt`/`WinHttp` (configurado em `ConfigureACBr`).
- Timeout: 60s.
