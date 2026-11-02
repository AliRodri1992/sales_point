# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    layout 'authentication'

    prepend_before_action :store_terminal_preferences, only: :new

    def new
      super
    end

    def create
      build_resource_with_params
      return render_with_model_errors unless valid_login_input?
      return render_invalid_credentials unless warden.authenticate(auth_options)

      super
      store_sign_in_success_message if user_signed_in?
    end

    private

    def require_no_authentication
      return super unless action_name == 'new' && user_signed_in?

      session[:swal_message_key] = 'devise.failure.already_authenticated'
      session[:swal_icon] = 'info'
      session[:swal_mode] = 'toast'
      redirect_to admin_dashboard_path
    end

    def set_flash_message!(action, kind, options = {})
      return if action.to_sym == :signed_in

      super
    end

    def store_sign_in_success_message
      flash.delete(:notice)
      flash.delete(:success)
      session[:swal_message] = t('devise.sessions.signed_in')
      session[:swal_icon] = 'success'
    end

    def render_with_model_errors
      render :new, status: :unprocessable_content
    end

    def render_invalid_credentials
      resource.password = nil
      @login_error = t('authentication.login.invalid_credentials')
      render :new, status: :unprocessable_content
    end

    def build_resource_with_params
      self.resource = resource_class.new
      resource.email = params.dig(resource_name, :email)
      resource.password = params.dig(resource_name, :password)
      resource.remember_me = params.dig(resource_name, :remember_me)
    end

    def valid_login_input?
      resource.errors.add(:email, :blank) if resource.email.blank?
      resource.errors.add(:email, :invalid) if invalid_login_email?
      resource.errors.add(:password, :blank) if resource.password.blank?
      resource.errors.empty?
    end

    def invalid_login_email?
      resource.email.present? && !resource.email.strip.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
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
