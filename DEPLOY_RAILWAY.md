# Deploy no Railway

Guia para deployar o **Base Rails App** no Railway.

Project ID: `<PROJECT_ID>`

## Pré-requisitos

1. `RAILWAY_TOKEN` configurado nas variáveis de ambiente do **Claude Code**
   (não no projeto Railway). É um Project Token criado em
   `railway.com/project/<id>/settings/tokens`.
2. As variáveis de ambiente do Claude Code são injetadas **no momento da criação
   do container** — se o token for adicionado a uma sessão já em andamento, é
   preciso **iniciar uma nova sessão** para que ele fique disponível.

## O que já está pronto na `main`

| Item | Arquivo |
|---|---|
| Builder Dockerfile, healthcheck `/up`, auto-migrate no start | `railway.toml` |
| Processos web (puma) + worker (sidekiq) | `Procfile` |
| Suporte a `DATABASE_URL` | `config/database.yml` |
| Action Cable montado em `/cable` quando `RAILWAY_ENVIRONMENT` presente | `config/application.rb` |
| Static files servidos + hosts `*.railway.app` liberados + URL do mailer | `config/environments/production.rb` |

## Passo a passo (via Railway CLI)

```bash
# 1. Verificar autenticação
echo ${#RAILWAY_TOKEN}        # deve ser > 0
railway whoami                # ou: railway status

# 2. Provisionar bancos
railway add --plugin postgresql
railway add --plugin redis

# 3. Configurar variáveis do serviço web
railway variables --set RAILS_ENV=production
railway variables --set SECRET_KEY_BASE=$(openssl rand -hex 64)
railway variables --set QUOTE_PROVIDER=manual
# URL_HOST e ACTION_CABLE_ALLOWED_REQUEST_ORIGINS: configurar após o domínio existir

# 4. Disparar deploy
railway up

# 5. (após o domínio existir) configurar host e WebSocket origins
railway variables --set URL_HOST=seu-app.up.railway.app
railway variables --set ACTION_CABLE_ALLOWED_REQUEST_ORIGINS=https://seu-app.up.railway.app
railway up   # redeploy para aplicar

# 6. Popular dados de exemplo (uma única vez)
railway run bundle exec rails db:seed
```

## Serviço worker (Sidekiq)

Criar um **segundo serviço** no mesmo projeto, apontando para o mesmo repo:

- **Start command:** `bundle exec sidekiq -C config/sidekiq.yml`
- **Variáveis:** as mesmas do web (incluindo `DATABASE_URL` e `REDIS_URL`,
  que o Railway injeta automaticamente ao referenciar os plugins).

O worker roda os jobs agendados via `sidekiq-cron`:
- `RefreshQuotesJob` — atualiza cotações durante o pregão (dias úteis, 10h–18h)
- `UpdateSelicRateJob` — atualiza a Selic via BCB API após reuniões do COPOM

## Variáveis de ambiente (resumo)

| Variável | Origem | Obrigatória |
|---|---|---|
| `DATABASE_URL` | Plugin PostgreSQL (auto) | sim |
| `REDIS_URL` | Plugin Redis (auto) | sim |
| `RAILWAY_ENVIRONMENT` | Railway (auto) | sim (ativa Action Cable em `/cable`) |
| `RAILS_ENV` | manual = `production` | sim |
| `SECRET_KEY_BASE` | manual (`openssl rand -hex 64`) | sim |
| `URL_HOST` | manual = domínio Railway | sim |
| `ACTION_CABLE_ALLOWED_REQUEST_ORIGINS` | manual = `https://<domínio>` | sim |
| `QUOTE_PROVIDER` | manual = `manual` / `brapi` / `oplab` | não (default `manual`) |
| `BRAPI_TOKEN` | manual (opcional) | não |
| `OPLAB_TOKEN` | manual (opcional) | não |

## Notas

- As migrations rodam automaticamente a cada deploy (`railway.toml` start command).
- O `db:seed` é manual de propósito, para não recriar dados a cada deploy.
- Após configurar `URL_HOST` / `ACTION_CABLE_ALLOWED_REQUEST_ORIGINS`, é necessário
  um redeploy para o tempo real (Turbo Streams via WebSocket) funcionar.
- Login de exemplo (do seed): `dev@example.com` / `password123`.
