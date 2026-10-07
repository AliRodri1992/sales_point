# frozen_string_literal: true

module TerminalHelper
  def terminal_themes
    Theme.all
  end

  def current_terminal_theme
    cookies[:terminal_theme].presence || Theme::DEFAULT
  end

  def terminal_theme_selected?
    cookies[:terminal_theme_selected].present?
  end

  def terminal_languages
    Language.available
  end

  def current_terminal_language
    session[:language] || 'en'
  end

  def current_language
    @current_language ||=
      Language.find_by(
        id: session[:language_id]
      ) ||
      Language.available.first
  end

  def current_language_flag
    current_language
  end

  def language_flag_path(language)
    image_path("flags/#{language.flag_iso}.svg")
  end
end
