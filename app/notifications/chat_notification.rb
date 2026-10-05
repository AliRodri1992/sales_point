# frozen_string_literal: true

class ChatNotification < Noticed::Event
  required_param :message

  delegate :conversation, to: :message

  def message
    params[:message]
  end

  def sender
    message.user
  end
end
