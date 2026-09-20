class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(:created_at)
    mark_notifications_as_read
    render layout: false
  end

  def create
    participant = User.find(params[:participant_id])
    @conversation = Conversation.find_or_create_direct(current_user, participant)
    @messages = @conversation.messages.order(:created_at)
    mark_notifications_as_read

    render :show, layout: false
  end

  private

  def mark_notifications_as_read
    unread = current_user.message_notifications_for(@conversation).unread
    return if unread.none?

    unread.mark_as_read
    current_user.broadcast_notifications_refresh
  end
end
