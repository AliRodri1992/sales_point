# frozen_string_literal: true

module TerminalHelper
  def terminal_themes
    Theme.all
  end

  def current_terminal_theme
    session[:theme].presence || Theme::DEFAULT
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

  def flag_url(language, size = '64x48')
    language.flag_url(size)
  end

  def flag_srcset(language)
    language.flag_srcset
  end
end
