class Rack::Attack
  # 🚫 bloquear IPs sospechosas (opcional)
  # Rack::Attack.blocklist("block bad IPs") do |req|
  #   ["1.2.3.4"].include?(req.ip)
  # end

  # 🔐 Throttle login attempts
  throttle("login attempts per IP", limit: 5, period: 60.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  # 🔐 Throttle general requests per IP
  throttle("requests by IP", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # 🚫 proteger rutas sensibles
  throttle("admin abuse", limit: 10, period: 1.minute) do |req|
    req.path.start_with?("/admin") ? req.ip : nil
  end

  # 🧯 respuesta cuando se bloquea
  self.throttled_response = lambda do |_env|
    [429, {}, ["Too many requests. Try again later."]]
  end
end
