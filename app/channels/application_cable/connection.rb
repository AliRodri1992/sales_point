module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      return unless current_user

      @presence_token = SecureRandom.uuid
      User.track_online_connection(current_user.id, @presence_token)
      broadcast_presence
    end

    def disconnect
      return unless current_user

      User.untrack_online_connection(current_user.id, @presence_token) if @presence_token
      broadcast_presence
    end

    # Action Cable invokes beat periodically while the socket stays connected.
    def beat
      User.track_online_connection(current_user.id, @presence_token) if current_user && @presence_token
      super
    end

    private

    def find_verified_user
      user_id = cookies.signed[:user_id]
      return unless user_id

      User.find_by(id: user_id) || reject_unauthorized_connection
    end

    def broadcast_presence
      online_ids = User.online_user_ids
      users = User.where(id: online_ids, status: :active)
      users.find_each do |viewer|
        Turbo::StreamsChannel.broadcast_replace_to(
          "presence_#{viewer.id}",
          target: 'online_users_list',
          partial: 'admin/shared/online_users_list',
          locals: { users: users, viewer: viewer }
        )
      end
    end
  end
end
