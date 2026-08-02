require 'sidekiq/web'

Rails.application.routes.draw do
  patch '/language', to: 'languages#update'

  devise_for :users,
             controllers: {
               sessions: 'users/sessions'
             }

  authenticated :user do
    root 'dashboard#index', as: :authenticated_root
  end

  unauthenticated do
    root to: redirect { |_params, _request|
      Rails.application.routes.url_helpers.new_user_session_path
    }
  end

  get 'up' => 'rails/health#show', as: :rails_health_check

  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
    mount MissionControl::Jobs::Engine, at: '/jobs'
  end
end
