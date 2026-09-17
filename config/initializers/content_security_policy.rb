# frozen_string_literal: true

Rails.application.config.content_security_policy do |policy|

  policy.default_src :self

  policy.font_src(
    :self,
    "https://fonts.gstatic.com",
    :data
  )

  policy.img_src(
    :self,
    :https,
    :data,
    "https://flagcdn.com"
  )

  policy.script_src(
    :self,
    :https
  )

  policy.style_src(
    :self,
    "https://fonts.googleapis.com",
    :unsafe_inline
  )

  policy.object_src :none
end