class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale

  private

  def set_locale
    if user_signed_in? && current_user.language
      I18n.locale = current_user.language.code.downcase.to_sym
    elsif session[:language_id].present?
      language = Language.find_by(id: session[:language_id])
      I18n.locale = language.code.downcase.to_sym if language
    end
  end
end
