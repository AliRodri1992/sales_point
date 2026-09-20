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
    current_user.message_notifications_for(@conversation).unread.mark_as_read
    refresh_notifications_badge
  end

  def refresh_notifications_badge
    Turbo::StreamsChannel.broadcast_replace_to(
      "notifications_#{current_user.id}",
      target: 'notifications_badge',
      partial: 'admin/shared/notifications_badge',
      locals: { user: current_user }
    )
  end
end
