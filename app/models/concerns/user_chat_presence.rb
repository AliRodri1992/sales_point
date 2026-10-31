# frozen_string_literal: true

# Tracks individual websocket connections, so multiple browser tabs count as
# one person and abandoned sockets disappear after missed heartbeats.
module UserChatPresence
  PRESENCE_TIMEOUT = 60

  def presence_redis
    Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end

  def track_online_connection(user_id, token)
    presence_redis.zadd(ONLINE_USERS_KEY, Time.current.to_i, "#{user_id}:#{token}")
  end

  def untrack_online_connection(user_id, token)
    presence_redis.zrem(ONLINE_USERS_KEY, "#{user_id}:#{token}")
  end

  def online_user_ids
    redis = presence_redis
    cutoff = Time.current.to_i - UserChatPresence::PRESENCE_TIMEOUT
    redis.zremrangebyscore(ONLINE_USERS_KEY, '-inf', cutoff)
    redis.zrange(ONLINE_USERS_KEY, 0, -1).map { |member| member.to_s.split(':', 2).first.to_i }.uniq
  end
end
