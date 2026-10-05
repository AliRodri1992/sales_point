# frozen_string_literal: true

class LanguagesController < ApplicationController
  def update
    language = Language.available.find_by!(code: params[:language].downcase)

    update_session_and_cookies(language)
    update_user_language(language) if user_signed_in?
    I18n.locale = language.code.downcase.to_sym

    render json: { success: true }
  end

  private

  def update_session_and_cookies(language)
    session[:language_id] = language.id
    cookies[:terminal_language] = {
      value: language.code.downcase,
      path: '/',
      max_age: 31_536_000
    }
  end

  def update_user_language(language)
    current_user.update!(language_id: language.id)
  end
end
