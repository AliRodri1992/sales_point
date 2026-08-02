# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController

    layout 'authentication'


    before_action :store_terminal_preferences, only: :new


    def create

      super do |resource|

        persist_terminal_preferences(resource)

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


  end
end