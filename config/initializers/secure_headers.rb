SecureHeaders::Configuration.default do |config|
  config.cookies = {
    secure: true,
    httponly: true,
    samesite: {
      lax: true
    }
  }

  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0"

  config.referrer_policy = %w[strict-origin-when-cross-origin]

  config.hsts = "max-age=63072000; includeSubDomains; preload"

  config.csp = {
    default_src: %w['self'],
    script_src: %w['self' 'unsafe-inline' https:],
    style_src: %w['self' 'unsafe-inline'],
    img_src: %w['self' data:],
    connect_src: %w['self'],
    font_src: %w['self'],
    object_src: %w['none'],
    frame_ancestors: %w['none']
  }
end
