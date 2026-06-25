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
  resources :habits
  post "habits/:id/toggle", to: "habit_checks#toggle", as: :toggle_habit

  namespace :admin do
    root to: "dashboard#index"
    resources :memberships, only: [:update, :destroy]
    resources :users, only: [:index, :update]
    resources :accounts, only: [:index]
  end

  require "sidekiq/web"
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end
end
