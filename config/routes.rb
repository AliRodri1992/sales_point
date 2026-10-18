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
      resources :inventories, only: %i[index create update] do
        member { post :adjust }
        resources :inventory_lots, only: :index
      end
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
    resources :purchase_requests, except: %i[destroy] do
      member do
        post :submit
        post :approve
        post :reject
        post :cancel
      end
    end
    resources :purchase_quotations, except: %i[destroy] do
      member do
        post :submit
        post :accept
        post :reject
      end
    end
    resources :purchase_orders, except: %i[destroy] do
      resources :goods_receipts, only: %i[index new create]
      member do
        post :submit
        post :approve
        post :reject
        post :send_order
        post :cancel
        post :close
      end
    end
    resources :goods_receipts, only: %i[show] do
      resources :purchase_returns, only: %i[new create]
    end
    resources :purchase_returns, only: %i[index show] do
      member { post :process_return }
    end

    resources :account_payables, only: %i[index show]
    resources :supplier_invoices, except: %i[destroy] do
      collection { post :preview_cfdi }
      member do
        post :post_invoice
        post :cancel
        post :match_receipts
        get :download_xml
        get :download_pdf
      end
    end
    resources :supplier_payments, only: %i[index show new create] do
      member do
        post :post_payment
        post :reverse
      end
    end
    resources :supplier_credit_notes, only: %i[index show new create] do
      member do
        post :post_credit
        get :download_xml
        post :apply
        post :cancel
      end
    end

    get 'supplier_postal_suggestions', to: 'supplier_postal_codes#show', as: :supplier_postal_suggestions

    resources :suppliers do
      member { get :contacts_page }
      member { get :addresses_page }
      member { get :postal_code_suggestions, to: 'supplier_postal_codes#show' }
      resources :bank_accounts, controller: 'supplier_bank_accounts', except: %i[show] do
        member { post :reveal }
      end

      resources :supplier_products, path: 'products', except: %i[show] do
        member do
          get :history
          post :set_preferred
          post :clear_preferred
        end
      end
      get 'products/:product_id/comparison', to: 'supplier_product_comparisons#show', as: :product_comparison
      collection { get :export }

      get 'documents/:document_id/download', to: 'supplier_documents#download', as: :document_download
      delete 'documents/:document_id', to: 'supplier_documents#destroy', as: :document
      resources :schedules, controller: 'supplier_schedules', except: %i[show] do
        member { patch :restore }
      end
      resources :contacts, controller: 'supplier_contacts', except: %i[show] do
        member { patch :restore }
      end
      resources :addresses, controller: 'supplier_addresses', except: %i[show] do
        member do
          patch :restore
          patch :set_primary
        end
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
