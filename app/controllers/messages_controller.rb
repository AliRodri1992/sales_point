class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation

  def create
    @message = @conversation.messages.create(user: current_user, body: message_params[:body])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "new_message_form_#{@conversation.id}",
          partial: 'messages/form',
          locals: {
            conversation: @conversation,
            message: @message.persisted? ? Message.new : @message
          }
        )
      end
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  def message_params
    params.expect(message: [:body])
  end
end
