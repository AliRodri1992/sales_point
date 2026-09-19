class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(:created_at)
    render layout: false
  end

  def create
    participant = User.find(params[:participant_id])
    @conversation = Conversation.find_or_create_direct(current_user, participant)
    @messages = @conversation.messages.order(:created_at)

    render :show, layout: false
  end
end
