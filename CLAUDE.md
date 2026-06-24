# CLAUDE.md

Orientações para o Claude Code (e qualquer dev) trabalhar neste repositório.

## O que é

**Base Rails App** — esqueleto (template) Rails 8 multi-tenant para iniciar novos
projetos. Já vem com **autenticação** (e-mail/senha + Google OAuth via Devise),
**roles cumulativas** (`admin`/`super_admin`), **multi-tenant** (contas +
memberships + onboarding com aprovação), um **painel `/admin`** próprio (Tailwind)
e o **`/super_admin`** (ActiveAdmin), tudo containerizado e pronto pra Railway +
Cloudflare.

A ideia é **clonar este repo, renomear, e adicionar o domínio do seu projeto** —
a "casca" de auth/roles/admin/deploy já está resolvida.

## Stack

- Rails 8.1, Ruby 4.0.5
- PostgreSQL, Redis
- Sidekiq + sidekiq-cron (jobs/agendamento)
- Hotwire (Turbo + Stimulus) — sem SPA
- Devise + OmniAuth (Google)
- Tailwind CSS (cssbundling) + esbuild (jsbundling) + Propshaft
- ActiveAdmin (em `/super_admin`) — assets via **dart-sass** (ver gotcha abaixo)
- RSpec + FactoryBot + Faker
- Docker / docker-compose (dev) · Railway (produção) · Cloudflare (domínio)

## Domínio da casca

| Model | Papel |
|---|---|
| `User` | Devise (database + omniauth Google). `name`, `provider`/`uid`. |
| `Role` | Role nomeada (`admin`, `super_admin`, `member`). HABTM com User. |
| `Account` | Tenant. `name`, `join_code`, `owner`. |
| `Membership` | Vínculo User↔Account. `role` (owner/admin/member), `status` (pending/active). |

### Autorização (roles, cumulativas)

- `User#role?(name)`, `#add_role`, `#remove_role`.
- `User#platform_admin?` = `role?(:admin)` → acesso ao **`/admin`**.
- `User#super_admin?` = `role?(:super_admin)` → acesso ao **`/super_admin`** (ActiveAdmin).
- Um usuário pode ter várias roles e elas **se somam**.
- **Bootstrap do 1º admin:** a migration `SeedRolesAndBootstrapAdmins` concede
  `admin`+`super_admin` aos e-mails de `ENV["PLATFORM_ADMIN_EMAILS"]` (uma vez, no
  deploy). Em runtime, quem manda são as roles no banco (geridas no `/admin`).

### Multi-tenant

- Novo usuário sem conta ativa cai no **onboarding** (`OnboardingController`):
  cria conta ou pede entrada por código (`JoinRequest`).
- `ApplicationController#require_account` gateia o app: sem conta ativa →
  `/onboarding` ou `/pending`.
- Conta criada por não-admin nasce `pending` (aprovação manual no `/admin`).

### Painéis admin

- **`/admin`** (Tailwind próprio, `Admin::BaseController` gateado por
  `platform_admin?`): aprovações de membership, gestão de **roles** por usuário,
  listagem de contas.
- **`/super_admin`** (ActiveAdmin, gateado por `super_admin?` via
  `SuperAdminAuthentication`): CRUD dos models. Adicione resources em `app/admin/`.

## ⚠️ Gotcha — assets do ActiveAdmin no Propshaft

ActiveAdmin pressupõe Sprockets/Sass; este stack é Propshaft + cssbundling. A
solução já montada:
- **JS:** `app/javascript/active_admin.js` (`import "@activeadmin/activeadmin"`) →
  esbuild → `app/assets/builds/active_admin.js`.
- **CSS:** `app/assets/stylesheets/active_admin.scss` → **dart-sass** →
  `app/assets/builds/active_admin.css`, **wirado no `./run yarn:build:css`** (logo
  roda no `assets:precompile` de prod).
- `ransackable_attributes/associations` liberados no `ApplicationRecord` (AA é
  super-admin-only). `rails-i18n` p/ os formatos pt-BR usados pelo AA.

Não troque o pipeline sem testar `assets:precompile` (é o que quebra em prod).

## Convenções

- **Lógica de negócio em service objects** (`app/services/`), não em controllers/models.
- **Timezone** `America/Sao_Paulo`, **locale** `pt-BR`. Textos de UI em português.
- **Git: commitar direto na `main`.** Não criar branches.

## Comandos

```bash
cp .env.example .env
docker compose up --build
docker compose exec web bin/rails db:prepare db:seed
docker compose exec web bundle exec rspec
./run quality      # rubocop
```

Login dev (seed): `dev@example.com` / `password123` (já é admin + super_admin).

## Deploy

Antes de **qualquer deploy/migração/comando em produção**, leia
**`DEPLOY_OPERACOES.md`** (runbook: deploy via GraphQL API do Railway, one-off via
`startCommand`, verificação por `curl`) e **`DEPLOY_RAILWAY.md`** (setup inicial).
O domínio customizado (Cloudflare + Railway) está no `DEPLOY_OPERACOES.md` §7.
**Preencha os IDs/domínio do SEU projeto** — os runbooks usam placeholders `<...>`.
