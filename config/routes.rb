Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Login do app nativo (Caminho B): reusa o OAuth Google web via navegador
  # embutido; o callback devolve o token por deep link lifeapp://.
  get "mobile/login", to: "mobile_auth#login"
  get "mobile/enter", to: "mobile_auth#enter" # ponte token->sessão (WebView do app)

  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end

  devise_scope :user do
    root to: "devise/sessions#new"
  end

  get "/up", to: "up#index", as: :up
  get "/up/databases", to: "up#databases", as: :up_databases

  # Multi-tenant: onboarding, contas e vínculos (memberships).
  get "/onboarding", to: "onboarding#show", as: :onboarding
  get "/pending", to: "onboarding#pending", as: :pending_approval
  resources :accounts, only: [:new, :create, :edit, :update] do
    member do
      post :switch
    end
    resources :members, only: [:index, :update, :destroy], controller: "memberships"
  end
  resources :join_requests, only: [:new, :create]

  # Domínio de tracking
  # Atividade foi absorvida pelo Dashboard (raiz); mantém redirect do link antigo.
  get "/activity", to: redirect { |_p, req| req.query_string.present? ? "/?#{req.query_string}" : "/" }
  get "/insights", to: "insights#index", as: :insights
  resources :habits
  resources :habit_categories, only: [:create, :update, :destroy]
  post "habits/:id/toggle", to: "habit_checks#toggle", as: :toggle_habit
  resources :weights, only: [:create, :destroy]
  resources :measurements, only: [:index, :create, :destroy] do
    collection do
      post :import
      delete :destroy_exams
    end
  end
  resources :exam_results, only: [:create, :destroy]
  post "exam_groups/:id/favorite", to: "exam_group_favorites#toggle", as: :toggle_exam_group_favorite
  resources :goals, only: [:index, :create, :destroy]

  # Tarefas (kanban): quadros personalizáveis, colunas, tarefas e comentários.
  resources :task_boards, path: "tasks" do
    resources :task_columns, path: "columns", only: [:create, :update, :destroy]
    resources :tasks, path: "items", only: [:create]
  end
  resources :tasks, path: "task", only: [:show, :update, :destroy] do
    patch :move, on: :member
    resources :task_comments, path: "comments", only: [:create, :destroy]
  end
  get "configurar", to: "setup#index", as: :setup

  # Conectores (integrações que puxam dados sozinhas)
  resources :connectors, only: [:destroy] do
    member { post :sync }
    collection do
      post "github", action: :github_connect, as: :github_connect
      get "github/callback", action: :github_callback, as: :github_callback
    end
  end
  get "screen-time", to: "screen_time#index", as: :screen_time
  get "screen-time/token", to: "screen_time#token", as: :screen_time_token
  get "screen-time/app", to: "screen_time#app", as: :screen_time_app
  get "screen-time/history", to: "screen_time#history", as: :screen_time_history
  post "screen-time/token", to: "screen_time#regenerate", as: :regenerate_screen_time_token

  # Servidor MCP: assistentes de IA lendo os dados da conta (somente leitura).
  post "mcp(/:token)", to: "mcp#create", as: :mcp
  match "mcp(/:token)", to: "mcp#unsupported", via: [:get, :delete]
  match "mcp(/:token)", to: "mcp#preflight", via: :options

  # OAuth 2.1 do MCP: descoberta, cadastro de cliente, consentimento e tokens.
  get ".well-known/oauth-protected-resource(/*rest)", to: "oauth/metadata#protected_resource"
  get ".well-known/oauth-authorization-server(/*rest)", to: "oauth/metadata#authorization_server"
  match ".well-known/oauth-protected-resource(/*rest)", to: "oauth/metadata#preflight", via: :options
  match ".well-known/oauth-authorization-server(/*rest)", to: "oauth/metadata#preflight", via: :options
  get "oauth/authorize", to: "oauth/authorizations#new", as: :oauth_authorize
  post "oauth/authorize", to: "oauth/authorizations#create"
  delete "oauth/grants/:id", to: "oauth/authorizations#destroy", as: :oauth_grant
  post "oauth/register", to: "oauth/tokens#register", as: :oauth_register
  post "oauth/token", to: "oauth/tokens#create", as: :oauth_token
  post "oauth/revoke", to: "oauth/tokens#revoke", as: :oauth_revoke
  match "oauth/(:action_name)", to: "oauth/tokens#preflight", via: :options
  post "configurar/mcp", to: "setup#enable_mcp", as: :enable_mcp
  delete "configurar/mcp", to: "setup#disable_mcp", as: :disable_mcp

  # API de ingestão (token pessoal) — ex.: script do Mac enviando tempo de tela; app enviando saúde.
  namespace :api do
    post "usage", to: "usage#create"
    post "usage_raw", to: "usage#create_raw"
    post "metrics", to: "metrics#create"
    post "workouts", to: "workouts#create"
    post "tasks", to: "tasks#create"
    post "health_raw", to: "health_raw#create"
    get "exams", to: "exams#index"
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :memberships, only: [:update, :destroy]
    resources :users, only: [:index, :update]
    resources :accounts, only: [:index]
    resources :exam_extractions, only: [:index]
    resources :ingestion_logs, only: [:index]
    resources :exam_groups, only: [:index, :new, :create, :edit, :update]
    resources :exam_types, only: [:new, :create, :edit, :update, :destroy]
  end

  require "sidekiq/web"
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end
end
