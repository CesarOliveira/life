# Sync de Tempo de Uso por app (iPhone → Mac → Life)

Coleta o **tempo de uso por app** do iPhone e envia para o app Life
(`life.cesaroliveira.online`). Funciona porque o iPhone sincroniza o Tempo de Uso
para o Mac via iCloud; um script no Mac lê esse dado e faz `POST` na API.

> **Por que precisa do Mac?** A Apple não deixa nenhum app no iPhone exportar o
> tempo **por app** para um servidor. O único caminho suportado é o iPhone
> sincronizar para o Mac e o Mac ler o banco local. (Total diário dá pra mandar
> direto do iPhone via Atalhos, mas não a quebra por app.)

## 1. No iPhone
- **Ajustes → Tempo de Uso → Compartilhar Entre Dispositivos = ON.**
- Mesmo Apple ID do Mac, com 2FA. A 1ª sincronização pode levar algumas horas.

## 2. No Mac
1. Copie esta pasta para, por exemplo, `~/life-screentime/`.
2. **Full Disk Access**: Ajustes do Sistema → Privacidade e Segurança → Acesso
   Total ao Disco → adicione o **Terminal** (e/ou `/usr/bin/python3`). Sem isso o
   script não lê o `knowledgeC.db`.
3. Pegue seu **token** e o **endpoint** na página **"Tempo de tela"** do app.
4. Teste manualmente:
   ```bash
   LIFE_TOKEN="seu_token" \
   LIFE_ENDPOINT="https://life.cesaroliveira.online/api/usage" \
   python3 ~/life-screentime/screentime_sync.py
   ```
   Deve imprimir algo como `2026-06-24: 12 apps -> HTTP 200 {"ok":true,...}`.
   Recarregue a página "Tempo de tela" e veja os apps aparecerem.

## 3. Automatizar (launchd, a cada 6h)
1. Edite `com.life.screentime.plist`: troque `SEU_USUARIO`, o caminho do script,
   e cole `LIFE_TOKEN`.
2. Instale:
   ```bash
   cp com.life.screentime.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.life.screentime.plist
   launchctl start com.life.screentime   # roda agora
   ```
3. Logs em `/tmp/life-screentime.log` e `/tmp/life-screentime.err`.
4. Para parar/atualizar:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.life.screentime.plist
   ```

## Troubleshooting
- **`PermissionError: Operation not permitted` no knowledgeC.db** → falta Full Disk
  Access. Ligue para o **app de terminal que você usa** (Terminal/iTerm/VS Code/
  Warp/Ghostty…) em Ajustes do Sistema → Privacidade e Segurança → **Acesso Total
  ao Disco**, e **feche (Cmd+Q) e reabra o terminal** (a permissão só vale para
  processos novos).
- **Rodou mas "Sem eventos de uso no período"** → ou o sync do iPhone ainda não
  populou o Mac (espere), ou o filtro. Faça um teste de sanidade com o uso do
  PRÓPRIO Mac (não depende de sync):
  ```bash
  DEVICE_FILTER=local LIFE_TOKEN="seu_token" python3 .../screentime_sync.py
  ```
  Se aparecerem apps do Mac, a leitura funciona — aí é só ligar "Compartilhar
  Entre Dispositivos" no iPhone e esperar o iCloud sincronizar para usar `remote`.

## Config (variáveis de ambiente)
| Var | Default | O que é |
|---|---|---|
| `LIFE_TOKEN` | — | **Obrigatório.** Token da página Tempo de tela. |
| `LIFE_ENDPOINT` | `…/api/usage` | URL do endpoint. |
| `DEVICE` | `iphone` | Rótulo enviado junto. |
| `DEVICE_FILTER` | `remote` | `remote` = só o que veio sincronizado (~iPhone); `local` = só o Mac; `all` = tudo. |
| `DAYS` | `3` | Reenviar os últimos N dias (upsert idempotente — não duplica). |

## Notas e limitações
- **Device split é heurístico:** no knowledgeC, eventos do próprio Mac têm
  `ZSOURCE` nulo e os sincronizados (iPhone/iPad/Watch) têm `ZSOURCE` preenchido.
  Com só iPhone + Mac, `remote` ≈ iPhone. Se tiver iPad/Watch, pode misturar.
- **Schema não-oficial:** o `knowledgeC.db` é interno da Apple e pode mudar entre
  versões grandes de macOS/iOS — se parar de funcionar, o script precisa de ajuste.
- **Mac precisa ligar de vez em quando** para rodar e enviar. Se ficar dias
  desligado, os dados acumulam no iCloud e sobem quando ligar (não perde).
- O envio é **idempotente** por `(device, data, bundle_id)`: reenviar o mesmo dia
  sobrescreve, não duplica.
- **Token:** colado no `.plist`, ele fica em texto claro num arquivo do seu usuário.
  Trate como senha (deixe o `.plist` em `chmod 600`). Mais seguro: guardar no
  Keychain e ler no script (`security find-generic-password -w ...`) em vez de env.
  Se vazar, gere um novo na página "Tempo de tela" (invalida o antigo).
