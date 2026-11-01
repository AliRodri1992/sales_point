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

  # Per-IP limit prevents rotating identifiers from bypassing the sign-in throttle.
  throttle('login attempts by IP', limit: 5, period: 1.minute) do |request|
    request.ip if request.path == '/users/sign_in' && request.post?
  end

  # A second limit protects accounts across multiple source IP addresses.
  throttle('login attempts by email', limit: 20, period: 5.minutes) do |request|
    if request.path == '/users/sign_in' && request.post?
      credentials = request.params['user']
      email = credentials.is_a?(Hash) ? credentials['email'].to_s.strip.downcase : ''
      email if email.present?
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

  self.throttled_responder = lambda do |request|
    locale = request.cookies['terminal_language'].to_s.downcase.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)
    message = I18n.t('authentication.rate_limited', locale:)
    [429, { 'Content-Type' => 'text/plain; charset=utf-8', 'Retry-After' => '60' }, [message]]
  end
end
