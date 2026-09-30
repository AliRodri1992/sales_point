# frozen_string_literal: true

class TranslationGenerationNotification < Noticed::Event
  required_param :action
  required_param :user

  def action
    params[:action]
  end

  def user
    params[:user]
  end

  def record
    super || TranslationGeneration.with_deleted.find_by(id: record_id)
  end

  def message
    language = record&.language&.name || 'language'

    I18n.t(
      "admin.shared.notifications.translation_generation.#{action}",
      language: language,
      default: "Translation generation #{action} for #{language}"
    )
  end
end
