# frozen_string_literal: true

# Limit Uppy CDN styles and local blob previews to supplier editing only.
module SupplierEditUploadSecurity
  extend ActiveSupport::Concern

  included do
    content_security_policy(only: %i[edit update]) do |policy|
      policy.style_src :self, :unsafe_inline, 'https://releases.transloadit.com'
      policy.img_src :self, :data, :blob
      policy.worker_src :self, :blob
    end
  end
end
