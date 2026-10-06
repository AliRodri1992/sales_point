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

  config.csp = {
    default_src: %w['self'],
    script_src: %w['self' 'unsafe-inline' https:],
    style_src: %w['self' 'unsafe-inline'],
    img_src: %w['self' data: https://flagcdn.com'],
    connect_src: %w['self'],
    font_src: %w['self' data:],
    object_src: %w['none'],
    frame_ancestors: Rails.env.development? ? %w['self'] : %w['none']
  }
end
