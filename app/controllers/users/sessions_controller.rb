# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    layout 'authentication'

    before_action :store_terminal_preferences, only: :new

    def new
      super
    end

    def create
      super do |resource|
        persist_terminal_preferences(resource)

        # Move flash messages to SweetAlert2
        if flash[:notice]
          flash[:swal_message] = flash[:notice]
          flash.delete(:notice)
        elsif flash[:alert]&.match?(/already signed i/i)
          flash[:swal_message] = flash[:alert]
          flash.delete(:alert)
        end
      end
    end

    private

    def store_terminal_preferences
      cookies[:terminal_language] ||=
        'en'

      cookies[:terminal_theme] ||=
        'theme-material-red'
    end

    def persist_terminal_preferences(_resource)
      cookies[:terminal_language] =
        terminal_language

      cookies[:terminal_theme] =
        terminal_theme
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
