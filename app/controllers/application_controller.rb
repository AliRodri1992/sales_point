class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :set_action_cable_user_id_cookie

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:user_type])
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
    if user_signed_in? && current_user.language
      I18n.locale = current_user.language.code.downcase.to_sym
    elsif session[:language_id].present?
      language = Language.find_by(id: session[:language_id])
      I18n.locale = language.code.downcase.to_sym if language
    end
  end
end
