SecureHeaders::Configuration.default do |config|
  config.cookies = {
    secure: true,
    httponly: true,
    samesite: {
      lax: true
    }
  }

  # LetterOpenerWeb renders each email inside a same-origin iframe.
  # Keep the production clickjacking policy strict while allowing the local
  # development mail preview to render correctly.
  config.x_frame_options = Rails.env.development? ? "SAMEORIGIN" : "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0"

  config.referrer_policy = %w[strict-origin-when-cross-origin]

  config.hsts = "max-age=63072000; includeSubDomains; preload"

  # Rails' built-in Content Security Policy is the single source of truth.
  # OPT_OUT is required here; nil would restore SecureHeaders' default CSP.
  config.csp = SecureHeaders::OPT_OUT
end
