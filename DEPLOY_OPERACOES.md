# Deploy & Pipeline — Runbook Operacional

> **Leia este arquivo ANTES de qualquer deploy, migração, comando one-off em
> produção, ou mudança no CI/pipeline.** Complementa o `DEPLOY_RAILWAY.md`
> (que cobre o _setup_ inicial); aqui ficam os procedimentos do dia a dia e as
> soluções para problemas já enfrentados.

---

## 0. Resumo do ambiente

- **Produção:** Railway. Deploy é disparado por **push na `main`** (commit direto
  na main é a convenção do projeto — ver `CLAUDE.md`).
- **Migrations rodam automaticamente** a cada deploy, via `startCommand` do
  `railway.toml`.
- **Dois serviços** apontam para o mesmo repo e redeployam juntos a cada push:
  `web` (puma) e `worker` (sidekiq).
- No **ambiente remoto do Claude Code NÃO existe o `railway` CLI.** Toda operação
  com o Railway é feita pela **GraphQL API** com um _Project Access Token_.

### IDs do projeto (Railway)

| Recurso | ID |
|---|---|
| Project (`<your-app>`) | `<PROJECT_ID>` |
| Environment `production` | `<ENVIRONMENT_ID>` |
| Service `web` (`<your-app>`) | `<WEB_SERVICE_ID>` |
| Service `worker` | `<WORKER_SERVICE_ID>` |
| Postgres | `<POSTGRES_ID>` |
| Redis | `<REDIS_ID>` |

### Token

O token é injetado no ambiente do Claude Code como **`RAILWAY_TOKEN`**.
Para usar nos snippets, exporte-o:

```bash
export RAILWAY_TOKEN="$RAILWAY_TOKEN"
```

> Variáveis de ENV do Claude Code são injetadas **na criação do container**. Se o
> token não estiver presente, é preciso **iniciar uma sessão nova** — não dá para
> "recarregar" no meio.
>
> **Fallback:** o token também é mantido no **arquivo `.env`** do projeto
> (gitignored). Se `RAILWAY_TOKEN` não estiver no ENV da sessão, leia
> do `.env`:
>
> ```bash
> val() { grep -E "^[[:space:]]*(export[[:space:]]+)?$1=" .env | head -1 | sed -E 's/^[^=]*=//; s/^["'"'"']//; s/["'"'"']$//'; }
> export RAILWAY_TOKEN="$(val RAILWAY_TOKEN)"
> ```

---

## 1. Acompanhar um deploy (GraphQL API)

Função base usada em todos os snippets:

```bash
export RAILWAY_TOKEN="$RAILWAY_TOKEN"
gq() { curl -s -X POST https://backboard.railway.app/graphql/v2 \
  -H "Project-Access-Token: $RAILWAY_TOKEN" \
  -H "Content-Type: application/json" -d "$1"; }
```

Esperar o deploy mais recente do serviço **web** terminar (detecta o build em
andamento e faz polling até `SUCCESS`/`FAILED`):

```bash
ENV="<ENVIRONMENT_ID>"
WEB="<WEB_SERVICE_ID>"

# 1) achar o deploy em andamento
DEP=""
until [ -n "$DEP" ]; do
  DEP=$(gq "{\"query\":\"query { deployments(first: 1, input: { environmentId: \\\"$ENV\\\", serviceId: \\\"$WEB\\\" }) { edges { node { id status } } } }\"}" \
    | python3 -c "import sys,json;e=json.load(sys.stdin)['data']['deployments']['edges'][0]['node'];print(e['id'] if e['status'] in ('BUILDING','DEPLOYING','INITIALIZING') else '')" 2>/dev/null)
  sleep 5
done

# 2) aguardar o status final
for i in $(seq 1 70); do
  ST=$(gq "{\"query\":\"query { deployment(id: \\\"$DEP\\\") { status } }\"}" \
    | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['deployment']['status'])" 2>/dev/null)
  case "$ST" in SUCCESS) echo "SUCCESS $i"; break;; FAILED|CRASHED) echo "$ST $i"; break;; esac
  sleep 10
done
```

Ler logs de um deploy (filtrando erros/migrations):

```bash
gq "{\"query\":\"query { deploymentLogs(deploymentId: \\\"$DEP\\\", limit: 1000) { message } }\"}" \
  | python3 -c "
import sys,json
for l in json.load(sys.stdin)['data']['deploymentLogs']:
    m=l['message']
    if any(k in m for k in ['error','Error','PG::','migrat','Migrat','rails aborted','FATAL','Exception']):
        print(m[:300])"
```

> Para o **worker**, troque `WEB` pelo ID do serviço `worker`. Os dois serviços
> redeployam a cada push; verifique o worker se o que você mudou afeta jobs.

**Regra:** só declare "deploy pronto" depois de ver `SUCCESS`. Build leva ~2–4 min.

---

## 2. Comandos one-off em produção (migração de dados, reset, limpeza)

Não existe `railway run`/console interativo aqui. O padrão é **rodar um script
temporário no boot do container**, via `rails runner`, e depois reverter.

### Procedimento (sempre 2 deploys: aplicar → reverter)

1. **Escreva um script idempotente** em `db/<nome>.rb` (ex.: `db/cleanup_x.rb`).
   Use `puts "MARCADOR ..."` para confirmar o resultado pelos logs.
2. **Edite o `startCommand`** do `railway.toml`, inserindo o runner **entre** o
   `db:migrate` e o `puma`:

   ```bash
   startCommand = "bash -c 'DB_REAPING_FREQUENCY=0 bundle exec rails db:migrate && DB_REAPING_FREQUENCY=0 bundle exec rails runner db/<nome>.rb && exec bundle exec puma -C config/puma.rb'"
   ```
3. Commit + push → aguarde `SUCCESS` → **leia os logs** procurando seu marcador.
4. **Reverta** o `startCommand` para o original, **remova o script**
   (`git rm db/<nome>.rb`), commit + push, aguarde `SUCCESS`.

### Regras de ouro

- **`DB_REAPING_FREQUENCY=0`** em todo comando rails de boot (migrate/runner),
  para o reaper de conexões não interferir.
- **Idempotência:** o script roda no boot e pode reexecutar em restart. Use
  `find_or_create_by`, `where(...).destroy_all`, guards `return if ...`.
- **Nunca commite segredos.** Senhas/credenciais entram via **ENV**
  (ex.: `ENV.fetch("ACCESS_PASSWORD")`), nunca hard-coded no script.
- **Sempre reverta** o `startCommand`. Deixar o runner ativo faz o one-off rodar
  a cada deploy/restart.

> Histórico desta abordagem nos commits: criação de conta de acesso, reset de
> senha e limpeza de dados de teste foram todos feitos assim.

---

## 3. Migrations

- Rodam **automaticamente** no deploy (`railway.toml`). Não precisa rodar à mão.
- **`schema.rb` está em `version: 0`** (placeholder): o banco é construído a
  partir das **migrations**, e `schema_migrations` controla o que já rodou. Não
  confie no `schema.rb` para saber o estado — olhe as migrations aplicadas.
- **Timestamp** de migration nova precisa ser **maior** que o das existentes,
  senão o Rails a considera "já aplicada" e pula.
- Para mudanças de schema + dados, separe: uma migration de **schema**
  (colunas/índices) e uma de **backfill** de dados. A de backfill deve ser
  **idempotente** e tolerar linhas órfãs.
- Ao trocar índice único (ex.: de `(a, user_id)` para `(a, account_id)`), use
  `remove_index ..., if_exists: true` antes do `add_index`, e lembre que no
  Postgres **múltiplos `NULL` não colidem** em índice único — dá para criar o
  índice antes do backfill preencher a coluna.

---

## 4. Verificar a app em produção via `curl`

Health check (não exige auth):

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://<your-app>.up.railway.app/up
```

Fluxo autenticado (Devise) — **CSRF + cookie jar**:

```bash
D="https://<your-app>.up.railway.app"
CJ=$(mktemp)
TOKEN=$(curl -s -c "$CJ" "$D/users/sign_in" \
  | grep -oE 'name="authenticity_token" value="[^"]+"' | head -1 \
  | sed -E 's/.*value="([^"]+)".*/\1/')
curl -s -b "$CJ" -c "$CJ" -o /dev/null -w "%{http_code}\n" \
  --data-urlencode "authenticity_token=$TOKEN" \
  --data-urlencode "user[email]=...@..." \
  --data-urlencode "user[password]=..." \
  "$D/users/sign_in"
# agora $CJ tem a sessão — use -b "$CJ" nas próximas requisições
```

### ⚠️ Gotcha de CSRF (causa de `422` em testes via curl)

Uma página tem **vários formulários** (nav, _account switcher_, botões
`button_to`), cada um com seu próprio `authenticity_token`. Pegar
`grep ... | head -1` muitas vezes captura o token do **formulário errado** →
`422 Unprocessable`. **Extraia o token do formulário específico** que você vai
submeter (pelo `action`):

```bash
python3 -c "
import re
html=open('/tmp/page.html',encoding='utf-8').read()
for m in re.finditer(r'<form[^>]*action=\"([^\"]+)\"[^>]*>(.*?)</form>', html, re.S):
    action, block = m.group(1), m.group(2)
    if action.endswith('/accounts'):                      # <- o action que você quer
        tok=re.search(r'name=\"authenticity_token\" value=\"([^\"]+)\"', block)
        if tok: open('/tmp/tok.txt','w').write(tok.group(1))
"
```

Para `PATCH`/`DELETE` via `button_to`, lembre que o form é `POST` + campo
oculto `_method`; replique com `--data-urlencode "_method=patch"`.

> `422` em formulário quase sempre é **token errado**, não bug da app. Confirme
> com o token do form certo antes de "consertar" código.

---

## 5. Problemas já enfrentados (e a solução)

| Sintoma | Causa | Solução |
|---|---|---|
| Cadastro Devise falha com "Nome não pode ficar em branco" | Devise não permite campos customizados por padrão | `configure_permitted_parameters` no `ApplicationController` liberando `:name` em `sign_up`/`account_update` |
| `422` ao submeter formulário via `curl` | Token CSRF do form errado | Extrair token do `<form>` específico (ver §4) |
| `ActionView::MissingTemplate` numa action | Controller sem o template correspondente | Criar a view (ou remover a action/rota) |
| Erro ao trocar `has_one` → `has_many` | Código usava `.singular` em vários pontos | Varrer `grep -rn "\.<assoc>\b"` e atualizar controllers/views/jobs/includes |
| Build Docker quebrando no CI por lint | `hadolint` `DL3059` (RUN consecutivos), `RAILS_ENV` dev no build, cop `SpaceInsideArrayLiteralBrackets` | Mesclar `RUN`s, ajustar `RAILS_ENV`, desabilitar o cop no `.rubocop.yml` |

### Conhecido / em aberto

- **CI (`.github/workflows/ci.yml`) sobe o stack via `docker compose` (`./run
  ci:test`) e tem falhado por falta de memória (OOM) no runner.** Direções para
  investigar: reduzir serviços/paralelismo no `compose.yaml` de CI, limitar
  workers do Postgres/Redis, ou rodar os testes sem subir o stack completo.
  **Não trate o CI verde como pré-requisito de deploy enquanto isso não estiver
  resolvido** — o deploy do Railway é independente do CI.

---

## 6. Checklist antes de finalizar um deploy

1. `ruby -c` nos arquivos `.rb` alterados (e sanidade nos `.erb`).
2. Commit direto na `main` (convenção do projeto) com mensagem clara.
3. Push e **aguardar `SUCCESS`** (web e, se relevante, worker).
4. Se houve migration, conferir nos logs que rodou sem erro.
5. **Verificar o fluxo real** afetado via `curl` autenticado (não só HTTP 200 —
   checar conteúdo esperado).
6. Se rodou one-off: **start command revertido** e **script removido**.
7. Sem segredos commitados.

---

## 7. Domínio customizado (Cloudflare + Railway)

Setup feito para `<your-domain>` (zona `<your-zone>`
na Cloudflare, registrada na GoDaddy). Token Cloudflare via ENV — escopo **Zone →
DNS → Edit** na zona; **revogar após o uso**.

```bash
CF_TOKEN="<token>"
cf() { curl -s -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" "$@"; }
ZID=$(cf "https://api.cloudflare.com/client/v4/zones?name=<your-zone>" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['result'][0]['id'])")
```

### Passo a passo (o que funcionou)

1. **Railway — adicionar o domínio** (devolve o alvo CNAME em `requiredValue`):
   `customDomainCreate(input: { domain, projectId, environmentId, serviceId })`.
   Alvo retornado: ex. `<railway-cname-target>`.
2. **Cloudflare — zona precisa estar `active`.** Se `status: pending`, os
   **nameservers ainda não foram trocados no registrador** (GoDaddy →
   `*.ns.cloudflare.com`). Isso é **manual no registrador**, não dá pela API.
   Confira: `cf ".../zones/$ZID" | ... ['status']` e
   `dns.google/resolve?name=<zona>&type=NS`.
3. **Cloudflare — criar o CNAME `DNS-only` (proxied: false)** para o Railway
   emitir o cert (Let's Encrypt). Proxied (laranja) **quebra** o desafio ACME.
   ```bash
   cf -X POST ".../zones/$ZID/dns_records" \
     --data '{"type":"CNAME","name":"<subdomain>","content":"<railway-cname-target>","ttl":1,"proxied":false}'
   ```
4. **⚠️ GOTCHA PRINCIPAL — verificação de propriedade por TXT.** Para alguns
   domínios o Railway **exige um TXT** além do CNAME, senão o cert fica **preso
   para sempre** em `VALIDATING_OWNERSHIP` (sem mensagem de erro). Cheque os
   campos de diagnóstico do domínio:
   ```graphql
   domains(...) { customDomains { status {
     certificateStatus verified verificationDnsHost verificationToken
     certificateErrorMessage certificateRetryable } } }
   ```
   Se `verified: false`, crie o TXT em `verificationDnsHost` com o valor de
   `verificationToken`:
   ```bash
   cf -X POST ".../zones/$ZID/dns_records" \
     --data '{"type":"TXT","name":"_railway-verify.<subdomain>","content":"railway-verify=<token>","ttl":1}'
   ```
   Em ~poucos minutos o Railway re-checa → `verified: true` →
   `certificateStatus: VALID`. **Não recrie o domínio depois de criar o TXT** —
   recriar gera um token novo e invalida o TXT.
5. **App — host authorization.** `config.hosts` inclui `URL_HOST`; sem isso o
   Rails **bloqueia** o domínio novo. Atualizar (via `variableUpsert`) e
   redeployar:
   - `URL_HOST=<your-domain>`
   - `ACTION_CABLE_ALLOWED_REQUEST_ORIGINS=https://<your-domain>,https://<app>.up.railway.app`
     (separado por vírgula; mantenha o `.railway.app` para o real-time seguir
     funcionando nos dois domínios).
6. **Validar:** `curl https://<your-domain>/up` (200),
   redirect HTTP→HTTPS (301), e o status `certificateStatus: VALID` no Railway.

### Diagnóstico de cert preso (ordem de eliminação)

- **CAA:** `dns.google/resolve?name=<zona>&type=CAA` — um CAA restritivo bloqueia
  o emissor. (Aqui: sem CAA.)
- **DNSSEC:** DS órfão no registrador (de DNSSEC antigo) faz resolver validante
  dar SERVFAIL. Cheque `.../zones/$ZID/dnssec` e `type=DS` no pai. (Aqui:
  desabilitado, sem DS.)
- **Proxy:** o registro tem que resolver para IP do Railway, não da Cloudflare.
  `dns.google/resolve?name=<fqdn>&type=A` deve dar o IP do Railway; o HTTP deve
  responder com header `server: railway-edge`.
- **Verificação TXT (`verified:false`)** → §7.4. **Foi esta a causa real.**

> Proxy laranja (CDN/WAF) só **depois** do cert VALID, e exige SSL/TLS = **Full**.
> O setup atual está **DNS-only** (funciona e é o mais simples).

---

## 8. Login com Google (OmniAuth)

Implementado em `082f12e`. Devise `:omniauthable` + `omniauth-google-oauth2` +
`omniauth-rails_csrf_protection`. Callback em
`Users::OmniauthCallbacksController#google_oauth2`; `User.from_omniauth` cria ou
vincula por e-mail (Google entrega e-mail verificado). Migration `provider`/`uid`
(`20260623000001`) com índice único — **NULLs não colidem**, então usuários
antigos (sem OAuth) convivem com o índice.

### Credenciais (ENV)

`GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` — `.env` em dev, **Variables do
Railway em prod**. Setadas nos **dois** serviços (`web` e `worker`), porque os
dois bootam os mesmos initializers. Snippet do `variableUpsert` (a mutation que o
§0 menciona mas não mostrava):

```bash
# requer gq() do §1 e PROJ/ENVID/SVC setados
payload=$(SVC="$WEB" NAME="GOOGLE_CLIENT_ID" VAL="$valor" python3 -c '
import os,json
print(json.dumps({"query":"mutation($i: VariableUpsertInput!){ variableUpsert(input:$i) }",
"variables":{"i":{"projectId":os.environ["PROJ"],"environmentId":os.environ["ENVID"],
"serviceId":os.environ["SVC"],"name":os.environ["NAME"],"value":os.environ["VAL"]}}}))')
gq "$payload"   # -> {"data":{"variableUpsert":true}}
```

> O botão "Entrar com o Google" no login **só renderiza se `GOOGLE_CLIENT_ID`
> estiver presente** (`ENV[...].present?` na view). Isso serve de **verificação
> de deploy**: `curl .../users/sign_in | grep google_oauth2` confirma de uma vez
> que as gems carregaram, o ENV chegou e o app subiu.

### Redirect URIs (Google Cloud Console)

Cadastrados no OAuth client (projeto `civil-clarity-88019`):

| Ambiente | Redirect URI | JavaScript origin |
|---|---|---|
| dev | `http://localhost/users/auth/google_oauth2/callback` | `http://localhost` |
| prod | `https://<your-domain>/users/auth/google_oauth2/callback` | `https://<your-domain>` |

> ⚠️ Em dev use **`localhost`**, NÃO `app.localhost` — o Google rejeita
> redirect URIs em `.localhost`. Por isso o Traefik (`traefik/dynamic.yml`) atende
> **os dois** hosts; o fluxo do Google roda em `http://localhost`. O tempo-real
> segue funcionando porque o cable conecta em `/cable` relativo à origem.
