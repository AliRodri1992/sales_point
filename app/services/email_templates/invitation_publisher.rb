# frozen_string_literal: true

module EmailTemplates
  # Publishes a new design only for untouched, built-in legacy invitations.
  # Organization templates and revised global versions retain their history.
  class InvitationPublisher
    LEGACY_MARKERS = {
      'es' => [
        ['INVITACIÓN A TU EQUIPO', 'width="48"'],
        ['Invitación para unirte a Delta POS', 'width="44"']
      ],
      'en' => [['Invitation to join Delta POS', 'width="44"']],
      'ko' => [['Delta POS 초대 안내', 'width="44"']]
    }.freeze

    def self.ensure_published!
      InvitationContent::COPY.each_key { |locale| ensure_locale!(locale) }
    end

    def self.ensure_locale!(locale)
      data = InvitationContent.build(locale)
      template = find_or_create_template(locale, data)
      template.with_lock do
        publish_content!(template, data) if publish_needed?(template)
      end
      template
    end

    def self.find_or_create_template(locale, data)
      EmailTemplate.global.find_or_create_by!(key: 'user_invitation', locale:) do |record|
        record.assign_attributes(
          name: 'User invitation', category: 'security', status: 'draft', enabled: false,
          subject: data.fetch(:subject), html_body: data.fetch(:html_body),
          text_body: data.fetch(:text_body)
        )
      end
    end

    def self.publish_needed?(template)
      return stock_legacy?(template) if template.published_version

      !template.versions.exists? || template.status == 'draft'
    end

    def self.stock_legacy?(template)
      published = template.published_version
      return false unless published&.version_number == 1
      return false unless template.versions.one?

      LEGACY_MARKERS.fetch(template.locale, []).any? do |marker, size|
        published.html_body.include?(marker) && published.html_body.include?(size)
      end
    end

    def self.publish_content!(template, data)
      draft = template.new_draft!(actor: nil)
      draft.update!(
        subject: data.fetch(:subject), preheader: data.fetch(:preheader), html_body: data.fetch(:html_body),
        text_body: data.fetch(:text_body),
        allowed_variables: data.fetch(:allowed_variables)
      )
      draft.publish!(actor: nil)
    end
  end
end
