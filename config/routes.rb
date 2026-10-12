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
    get '/', to: 'dashboard#index', as: :root
    get '/onboarding', to: 'onboarding#show', as: :onboarding
    patch '/onboarding', to: 'onboarding#update'
    patch '/onboarding/reset', to: 'onboarding#reset', as: :onboarding_reset
    patch 'sidebar', to: 'sidebar#update'
    get 'languages/content', to: 'languages#content'
    resources :languages
    resources :categories
    resources :products
    resources :clients
    resources :demo_requests, only: %i[index show update]
    resources :branches, only: %i[index show new create edit update destroy] do
      member { patch :select }
    end
    resources :users
    resources :clients
    resource :profile, only: %i[show update]
    resource :organization, only: [] do
      resources :contacts, controller: 'organization_contacts', except: %i[show] do
        member { patch :restore }
      end
    end
    resources :suppliers do
      collection { get :export }

      delete 'documents/:document_id', to: 'supplier_documents#destroy', as: :document
      resources :schedules, controller: 'supplier_schedules', except: %i[show] do
        member { patch :restore }
      end
      resources :contacts, controller: 'supplier_contacts', except: %i[show] do
        member { patch :restore }
      end
      resources :addresses, controller: 'supplier_addresses', except: %i[show] do
        member { patch :restore }
      end
    end
  end
  resources :system_roles do
    member do
      patch :permissions, action: :update_permissions
    end
  end
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
