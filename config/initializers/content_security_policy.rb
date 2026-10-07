# frozen_string_literal: true

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self

  policy.font_src(
    :self,
    :data,
    "https://flagcdn.com"
  )

  policy.img_src(
    :self,
    :data
  )

  policy.script_src(
    :self,
    :https
  )

  policy.style_src(
    :self,
    :unsafe_inline
  )

  policy.object_src :none
end
