class Rack::Attack
  throttle("requests by IP", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  throttle("login attempts", limit: 5, period: 60.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      "#{req.ip}:#{req.params['email']}"
    end
  end

  throttle("supplier geocoding", limit: 15, period: 1.minute) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/admin/suppliers/\d+/address_location_suggestion\z})
  end

  throttle("supplier map tiles", limit: 45, period: 1.minute) do |req|
    req.ip if req.get? && req.path.match?(%r{\A/admin/suppliers/\d+/address_map\z})
  end

  throttle("admin abuse", limit: 10, period: 1.minute) do |req|
    next if req.path.match?(%r{\A/admin/suppliers/\d+/(address_map|address_location_suggestion)\z})

    req.ip if req.path.start_with?("/admin")
  end

  self.throttled_responder = lambda do |_req|
    [429, {}, ["Too many requests. Try again later."]]
  end
end
