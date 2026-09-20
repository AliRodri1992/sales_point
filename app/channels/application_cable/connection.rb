module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      return unless current_user

      online_users.add(current_user.id)
      broadcast_presence
    end

    def disconnect
      return unless current_user

      online_users.remove(current_user.id)
      broadcast_presence
    end

    private

    def find_verified_user
      user_id = cookies.signed[:user_id]
      return unless user_id

      User.find_by(id: user_id) || reject_unauthorized_connection
    end

    def online_users
      Kredis.set(User::ONLINE_USERS_KEY)
    end

    def broadcast_presence
      online_ids = online_users.members.map(&:to_i)
      users = User.where(id: online_ids).where(status: :active)

      Turbo::StreamsChannel.broadcast_replace_to(
        'presence',
        target: 'online_users_list',
        partial: 'admin/shared/online_users_list',
        locals: { users: users }
      )
    end
  end
end
