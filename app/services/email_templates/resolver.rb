# frozen_string_literal: true

module EmailTemplates
  class Resolver
    def self.call(key:, locale:, values:, organization: nil)
      template = EmailTemplate.resolve(key:, locale:, organization:)
      raise ActiveRecord::RecordNotFound, 'Published email template not found' unless template

      branding = EmailTemplates::Branding.values(organization: organization || template.organization)
      template.render_with(values.symbolize_keys.merge(branding))
    end
  end
end
