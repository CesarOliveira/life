# Tempo de tela do iPhone, coletado pelo Mac

Fonte única do tempo de tela do Life. O iPhone sincroniza o uso de apps com o Mac
pelo iCloud ("Compartilhar Entre Dispositivos"); o script lê esse histórico no
Mac, grava um CSV no Google Drive e envia para `POST /api/usage`.

O Atalho do iPhone foi aposentado em 2026-11. Não rode os dois ao mesmo tempo: a
página soma todos os registros e o uso seria contado em dobro.

## Arquivos

| Arquivo | Papel |
|---|---|
| `tempodetela.py` | Lê, soma por app e por dia, grava o CSV e envia ao Life. Só biblioteca padrão (Python 3.9+). |
| `nomes_apps.json` | Dicionário editável bundle id → nome. O nome é a chave do app no Life. Aqui vai só um exemplo; a lista real fica na instalação. |
| `tempodetela-runner.c` | Lançador para o launchd (ver "Acesso Total ao Disco"). |
| `online.cesaroliveira.tempodetela.plist` | LaunchAgent: todo dia às 06:15, `--dias 3`. |

Instalação em uso: `~/Scripts/tempodetela/` e `~/Library/LaunchAgents/`. Os
caminhos estão fixos no `.c` e no `.plist`; ajuste se mudar de pasta ou usuário.

## De onde vêm os dados

`~/Library/Biome/streams/restricted/App.InFocus/remote/<dispositivo>/` (arquivos
SEGB v2). O id do iPhone vai em `DEVICE_ID` no script (placeholder nesta cópia); a lista de dispositivos
fica na tabela `DevicePeer` de `~/Library/Biome/sync/sync.db`. O `knowledgeC.db`
do macOS 26 **não** tem o uso de apps do iPhone.

O script copia os arquivos para `/tmp` antes de ler e apaga a cópia no final.
Nunca escreve na pasta do Biome.

## Acesso Total ao Disco

A pasta do Biome é protegida. Em Ajustes do Sistema → Privacidade e Segurança →
Acesso Total ao Disco:

- **Execução manual:** libere o app de terminal em uso.
- **launchd:** libere o binário `tempodetela-runner`. Liberar o Python do Xcode
  não funciona. O runner chama o Python como processo filho, que herda a permissão.

Compilar o runner (recompilar muda a assinatura e exige liberar de novo):

```bash
clang -O2 -o tempodetela-runner tempodetela-runner.c
codesign -s - -i online.cesaroliveira.tempodetela-runner -f tempodetela-runner
```

## Token

O token da conta (página "Configurar Tempo de tela") fica no Chaves do macOS:

```bash
security add-generic-password -U -s tempodetela-life -a life -w
```

## Uso

```bash
python3 tempodetela.py                # ontem
python3 tempodetela.py --dias 28      # reenvia os últimos 28 dias
python3 tempodetela.py --sem-life     # só o CSV
launchctl kickstart -k gui/$(id -u)/online.cesaroliveira.tempodetela
tail ~/Library/Logs/tempodetela.log
```

Códigos de saída: 0 ok, 2 sem acesso ao Biome, 3 Drive não encontrado, 4 envio ao
Life falhou (o CSV é gravado mesmo assim).

## Limites

- O Mac guarda cerca de um mês do histórico do iPhone.
- O dado chega em lotes, com horas de atraso. Por isso cada execução reenvia os
  últimos 3 dias; o servidor faz upsert por (conta, dispositivo, dia, app).
- Sem uso de sites e sem apps usados pelo CarPlay.
- O formato SEGB é interno da Apple e pode mudar entre versões do macOS.
