# frozen_string_literal: true

class LanguagesController < ApplicationController
  def update
    language = Language.available.find_by!(code: params[:language])

    session[:language_id] = language.id

    I18n.locale = language.code.downcase.to_sym

    render json: { success: true }
  end
end
