# Base Rails App

Esqueleto **Rails 8 multi-tenant** para iniciar novos projetos: autenticação
(e-mail/senha + Google), roles (`admin`/`super_admin`), multi-tenant (contas +
memberships + onboarding com aprovação), painel **`/admin`** (Tailwind) e
**`/super_admin`** (ActiveAdmin). Docker + Railway + Cloudflare prontos.

## Usar como base de um novo projeto

1. Clone/copie este repo e renomeie.
2. (Opcional) renomeie o módulo `BaseRailsApp` em `config/application.rb` e o
   `COMPOSE_PROJECT_NAME` / `POSTGRES_*` no `.env.example`.
3. Adicione os models/controllers/views do **seu domínio**.

## Dev (Docker)

```bash
cp .env.example .env
docker compose up --build
docker compose exec web bin/rails db:prepare db:seed
```

Acesse `http://localhost:8000` (ou `http://app.localhost` via Traefik).
Login dev (seed): `dev@example.com` / `password123` — já é **admin + super_admin**.

- `/admin` — painel próprio (aprovações, roles, contas)
- `/super_admin` — ActiveAdmin (CRUD dos models)

## Login com Google

Crie um OAuth client (Web application) no Google Cloud Console e preencha
`GOOGLE_CLIENT_ID/SECRET` no `.env`. Redirect URI de dev:
`http://localhost/users/auth/google_oauth2/callback` (use `localhost`, **não**
`app.localhost` — o Google rejeita `.localhost`). Detalhes no `.env.example`.

## Testes

```bash
docker compose exec -e RAILS_ENV=test web bundle exec rspec
```

## Deploy

Railway (produção) + Cloudflare (domínio). Ver **`DEPLOY_RAILWAY.md`** (setup
inicial) e **`DEPLOY_OPERACOES.md`** (runbook operacional). Os runbooks usam
placeholders `<...>` — preencha com os IDs/domínio do seu projeto.

## Licença

Ver `LICENSE`.
