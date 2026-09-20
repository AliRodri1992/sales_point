require 'sidekiq/web'

Rails.application.routes.draw do
  patch '/language', to: 'languages#update'

  devise_for :users,
             controllers: {
               sessions: 'users/sessions',
               registrations: 'users/registrations'
             }

  root 'home#index'
  get '/home/index', to: 'home#index'
  get '/dashboard/index', to: 'dashboard#index'
  namespace :admin do
    post 'dashboard/preferences', to: 'dashboard#save_preferences'
    get '/dashboard', to: 'dashboard#index', as: :dashboard
    patch 'sidebar', to: 'sidebar#update'
  end
  resources :system_roles
  resources :demo_requests, only: %i[new create]
  resources :notifications, only: [] do
    collection do
      post :mark_all_read
    end
  end
  resources :conversations, only: %i[show create] do
    resources :messages, only: %i[create]
  end

  get 'up' => 'rails/health#show', as: :rails_health_check

  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
    mount MissionControl::Jobs::Engine, at: '/jobs' if defined?(MissionControl::Jobs)
  end
end
