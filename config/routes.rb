Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

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
  get "/activity", to: "activity#index", as: :activity
  get "/insights", to: "insights#index", as: :insights
  resources :habits
  post "habits/:id/toggle", to: "habit_checks#toggle", as: :toggle_habit
  resources :weights, only: [:create, :destroy]
  resources :measurements, only: [:index, :create, :destroy] do
    collection do
      post :import
      delete :destroy_exams
    end
  end
  resources :exam_results, only: [:create, :destroy]
  resources :goals, only: [:index, :create, :destroy]
  get "configurar", to: "setup#index", as: :setup
  get "screen-time", to: "screen_time#index", as: :screen_time
  get "screen-time/token", to: "screen_time#token", as: :screen_time_token
  get "screen-time/app", to: "screen_time#app", as: :screen_time_app
  get "screen-time/history", to: "screen_time#history", as: :screen_time_history
  post "screen-time/token", to: "screen_time#regenerate", as: :regenerate_screen_time_token

  # Atalho de Saúde (.shortcut) gerado com o token da conta, para o iPhone enviar
  # sono/passos para /api/metrics. Download autenticado (token só vai pro dono).
  get "saude-shortcut", to: "shortcuts#health", as: :health_shortcut

  # API de ingestão (token pessoal) — ex.: Atalho do iPhone enviando uso/saúde.
  namespace :api do
    post "usage", to: "usage#create"
    post "usage_raw", to: "usage#create_raw"
    post "metrics", to: "metrics#create"
    post "health_raw", to: "health_raw#create"
    get "exams", to: "exams#index"
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :memberships, only: [:update, :destroy]
    resources :users, only: [:index, :update]
    resources :accounts, only: [:index]
    resources :exam_extractions, only: [:index]
    resources :exam_groups, only: [:index, :new, :create, :edit, :update]
    resources :exam_types, only: [:new, :create, :edit, :update, :destroy]
  end

  require "sidekiq/web"
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end
end
