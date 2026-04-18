class Rack::Attack
  throttle("requests by IP", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  throttle("login attempts", limit: 5, period: 60.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      "#{req.ip}:#{req.params['email']}"
    end
  end

  throttle("admin abuse", limit: 10, period: 1.minute) do |req|
    req.path.include?("admin") ? req.ip : nil
  end

  self.throttled_responder = lambda do |_req|
    [429, {}, ["Too many requests. Try again later."]]
  end
end
