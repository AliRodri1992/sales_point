# frozen_string_literal: true

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self

  policy.font_src(
    :self,
    :data
  )

  policy.img_src(
    :self,
    :data,
    :blob
  )

  # Inline Uppy thumbnails and its local thumbnail worker use blob URLs.
  policy.worker_src :self, :blob

  # Turbo navigations retain the CSP of the page they started on, so this
  # pinned CDN host must be permitted on all admin pages, not just edit.
  policy.connect_src :self, 'https://releases.transloadit.com'

  policy.script_src(
    :self,
    :https
  )

  policy.style_src(
    :self,
    :unsafe_inline,
    'https://releases.transloadit.com'
  )

  policy.object_src :none
end
