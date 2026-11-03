# frozen_string_literal: true

module EmailTemplates
  class Resolver
    def self.call(key:, locale:, values:, organization: nil)
      template = EmailTemplate.resolve(key:, locale:, organization:)
      raise ActiveRecord::RecordNotFound, 'Published email template not found' unless template

      template.render_with(values)
    end
  end
end
