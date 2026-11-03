# frozen_string_literal: true

email_catalog_permissions = %w[
  email_templates.access email_templates.create email_templates.update
  email_templates.publish email_templates.archive email_templates.preview
  email_templates.send_test email_templates.versions email_branding.manage
  email_settings.manage email_template_audits.view
].freeze

email_catalog_permissions.each do |code|
  Permission.find_or_create_by!(code:) do |permission|
    permission.name = code.tr('._', ' ').titleize.first(80)
    permission.module_name = 'Communication'
    permission.description = "Email administration: #{code}"
    permission.status = :active
  end
end

email_catalog_keys = {
  'user_invitation' => 'Invitation to Delta POS',
  'user_invitation_resend' => 'Your Delta POS invitation was resent',
  'user_welcome' => 'Welcome to Delta POS',
  'password_recovery' => 'Reset your password',
  'password_changed' => 'Your password was updated',
  'account_suspended' => 'Your account was suspended',
  'account_reactivated' => 'Your account was reactivated',
  'security_alert' => 'Security notification',
  'email_changed' => 'Email address updated'
}.freeze

email_catalog_locales = %w[es en ko]

email_catalog_keys.each do |key, default_subject|
  email_catalog_locales.each do |locale|
    template = EmailTemplate.find_or_create_by!(key:, locale:, organization_id: nil) do |record|
      record.name = default_subject
      record.category = 'security'
      record.status = 'published'
      record.subject = default_subject
      record.html_body = '<p>Delta POS: {{recipient_name}}</p>'
      record.text_body = 'Delta POS: {{recipient_name}}'
      record.enabled = true
    end
    next if template.published_version

    version = template.versions.find_or_create_by!(version_number: 1) do |record|
      record.status = 'published'
      record.subject = template.subject
      record.html_body = template.html_body
      record.text_body = template.text_body
      record.allowed_variables = %w[recipient_name]
      record.published_at = Time.current
    end
    template.update!(published_version: version)
  end
end

EmailTemplate.global.where(published_version_id: nil).find_each do |template|
  version = template.versions.find_or_create_by!(version_number: template.version) do |record|
    record.status = 'published'
    record.subject = template.subject
    record.html_body = template.html_body
    record.text_body = template.text_body
    record.allowed_variables = %w[
      recipient_name invited_name organization_name activation_url expiration_hours
      current_year logo_url platform_logo status_label
    ]
    record.published_at = Time.current
  end
  template.update!(published_version: version)
end
