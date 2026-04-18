require 'sidekiq/web'

Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  mount Sidekiq::Web => '/sidekiq'
  mount MissionControl::Jobs::Engine, at: '/jobs'
  get 'up' => 'rails/health#show', as: :rails_health_check
end
