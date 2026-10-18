# frozen_string_literal: true

class Rack::Attack
  # Share the global rate limit by IP, but count authenticated admin requests
  # per user so coworkers on the same network retain independent quotas.
  def self.admin_discriminator(request)
    user_id = request.env['warden']&.user(:user)&.id
    user_id ? "user:#{user_id}" : "ip:#{request.ip}"
  end

  throttle('requests by IP', limit: 1_200, period: 5.minutes) do |request|
    request.ip
  end

  # Protect sign-in without raising the original five-attempt limit.
  throttle('login attempts', limit: 5, period: 1.minute) do |request|
    if request.path == '/users/sign_in' && request.post?
      "#{request.ip}:#{request.params['email']}"
    end
  end

  throttle('supplier geocoding', limit: 20, period: 1.minute) do |request|
    if request.post? && request.path.match?(%r{\A/admin/suppliers/\d+/address_location_suggestion\z})
      admin_discriminator(request)
    end
  end

  throttle('supplier map tiles', limit: 120, period: 1.minute) do |request|
    if request.get? && request.path.match?(%r{\A/admin/suppliers/\d+/address_map\z})
      admin_discriminator(request)
    end
  end

  throttle('admin abuse', limit: 120, period: 1.minute) do |request|
    next if request.path.match?(%r{\A/admin/suppliers/\d+/(address_map|address_location_suggestion)\z})

    admin_discriminator(request) if request.path.start_with?('/admin')
  end

  self.throttled_responder = lambda do |_request|
    [429, { 'Content-Type' => 'text/plain; charset=utf-8' }, ['Too many requests. Try again later.']]
  end
end
