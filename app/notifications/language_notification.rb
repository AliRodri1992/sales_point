# frozen_string_literal: true

class LanguageNotification < Noticed::Event
  required_param :action

  delegate :name, :code, :flag_iso, to: :record

  def action
    params[:action] || 'updated'
  end
end
