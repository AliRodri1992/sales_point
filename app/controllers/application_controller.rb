class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :set_action_cable_user_id_cookie

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  helper_method :current_language, :current_organization, :available_branches, :current_branch

  def current_organization
    return unless current_user

    @current_organization ||= current_user.organizations.active_records.first
  end

  def available_branches
    return Branch.none unless current_organization

    current_organization.branches.not_deleted.where(status: true).order(:name)
  end

  def current_branch
    return unless current_organization

    branch = available_branches.find_by(id: session[:current_branch_id])
    branch || available_branches.first
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[email password password_confirmation theme])
  end

  def set_action_cable_user_id_cookie
    return unless user_signed_in?
    return if cookies.signed[:user_id] == current_user.id

    cookies.signed[:user_id] = {
      value: current_user.id,
      httponly: true,
      same_site: :lax
    }
  end

  def set_locale
    locale = preferred_locale || I18n.default_locale
    I18n.locale = locale if I18n.available_locales.include?(locale)
  end

  def preferred_locale
    user_language_code || session_language_code || cookie_language_code
  end

  def cookie_language_code
    code = cookies[:terminal_language].presence
    return unless code

    code.downcase.to_sym if I18n.available_locales.include?(code.downcase.to_sym)
  end

  def user_language_code
    user = current_user || request.env['warden']&.user
    return unless user&.language

    user.language.code.downcase.to_sym
  end

  def session_language_code
    language = Language.find_by(id: session[:language_id])
    return unless language

    language.code.downcase.to_sym
  end

  def current_language
    return current_user.language if user_signed_in? && current_user.language

    language = Language.find_by(id: session[:language_id])
    return language if language

    language = Language.available.find_by(code: cookies[:terminal_language].to_s.downcase)
    return language if language

    Language.available.first
  end

  def forbidden
    head :forbidden
  end
end
