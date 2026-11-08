# frozen_string_literal: true

module EmailTemplates
  # Creates one unpublished, tenant-owned draft from a published global template.
  # Unique (organization, key, locale) indexes keep retries idempotent.
  class Personalizer
    def self.call(source:, organization:, actor:)
      unless source.organization_id.nil? && source.status == 'published' &&
             source.enabled? && source.published_version && organization&.persisted?
        raise ArgumentError, 'A published global template and organization are required'
      end

      EmailTemplate.transaction do
        template = EmailTemplate.create_or_find_by!(
          organization:, key: source.key, locale: source.locale
        ) do |record|
          record.assign_attributes(
            source_template: source, name: source.name, category: source.category,
            subject: source.published_version.subject, html_body: source.published_version.html_body,
            text_body: source.published_version.text_body, status: 'draft', enabled: false,
            created_by: actor, updated_by: actor
          )
        end
        created = template.previously_new_record?
        create_draft!(template, source.published_version, actor) if created
        [template, created]
      end
    end

    def self.create_draft!(template, source_version, actor)
      draft = template.versions.create!(
        version_number: 1, status: 'draft', created_by: actor,
        subject: source_version.subject, preheader: source_version.preheader,
        html_body: source_version.html_body, text_body: source_version.text_body,
        allowed_variables: source_version.allowed_variables
      )
      template.audit!(action: 'personalized', actor:, version: draft)
    end
  end
end
