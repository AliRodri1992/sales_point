# frozen_string_literal: true

module Users
  # Clarifies the safe acceptance flow without rewriting published email templates.
  class ExistingInvitationPresentation
    def self.call(html:, plain:, locale:, organization_name:)
      code = EmailTemplates::InvitationContent::COPY.key?(locale.to_s) ? locale.to_s : 'es'
      copy = EmailTemplates::InvitationContent::COPY.fetch(code)
      substitutions = {
        copy.fetch(:action) => I18n.t('user_invitations.join', locale: code),
        copy.fetch(:invite) => I18n.t('user_invitations.existing_mail_invite', locale: code),
        copy.fetch(:guide) => I18n.t('user_invitations.existing_mail_guide', locale: code),
        copy.fetch(:preheader).gsub('{{organization_name}}', ERB::Util.html_escape(organization_name)) =>
          I18n.t('user_invitations.existing_mail_preheader', locale: code)
      }
      substitutions.each do |old, replacement|
        html = html.gsub(old, replacement)
        plain = plain.gsub(old, replacement)
      end

      note = I18n.t('user_invitations.existing_account', locale: code)
      [insert_notice(html, note), "#{note}\n\n#{plain}"]
    end

    def self.insert_notice(html, note)
      message = %(<p style="color:#065f46;font-size:14px;line-height:1.6;">#{ERB::Util.html_escape(note)}</p>)
      return html.sub('</h1>', "</h1>#{message}") if html.include?('</h1>')

      "#{message}#{html}"
    end
    private_class_method :insert_notice
  end
end
