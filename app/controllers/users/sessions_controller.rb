# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    layout 'authentication'

    before_action :store_terminal_preferences, only: :new

    def new
      super
    end

    def create
      super
    end

    private

    def store_terminal_preferences
      cookies[:terminal_language] ||=
        'en'

      cookies[:terminal_theme] ||=
        'theme-material-red'
    end

    def terminal_language
      params
        .dig(:terminal, :language)
        .presence ||
        cookies[:terminal_language] ||
        'en'
    end

    def terminal_theme
      params
        .dig(:terminal, :theme)
        .presence ||
        cookies[:terminal_theme] ||
        'theme-material-red'
    end

    def after_sign_in_path_for(_resource)
      admin_dashboard_path
    end
  end
end
