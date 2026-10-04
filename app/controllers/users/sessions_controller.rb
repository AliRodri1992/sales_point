# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    layout 'authentication'

    before_action :store_terminal_preferences, only: :new

    def new
      super
    end

    def create
      return render_with_model_errors unless login_credentials_present?

      super
      store_sign_in_success_message if user_signed_in?
    end

    private

    def store_sign_in_success_message
      session[:swal_message] = t('devise.sessions.signed_in')
      session[:swal_icon] = 'success'
      flash.delete(:notice)
    end

    def render_with_model_errors
      build_resource_with_params
      resource.valid?
      flash.now[:alert] = t('devise.failure.invalid')

      render :new, status: :unprocessable_content
    end

    def build_resource_with_params
      self.resource = resource_class.new
      resource.email = params.dig(resource_name, :email)
      resource.password = params.dig(resource_name, :password)
    end

    def login_credentials_present?
      params.dig(resource_name, :email).present? &&
        params.dig(resource_name, :password).present?
    end

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
