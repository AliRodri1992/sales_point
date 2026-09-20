class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def mark_all_read
    current_user.unread_notifications.mark_as_read

    respond_to do |format|
      format.turbo_stream
    end
  end
end
