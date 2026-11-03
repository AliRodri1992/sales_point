# frozen_string_literal: true

module Users
  class SessionRevoker
    def self.call(user)
      ActionCable.server.remote_connections.where(current_user: user).disconnect
    rescue StandardError => e
      Rails.logger.warn("Unable to disconnect existing user sockets: #{e.class}")
    end
  end
end
