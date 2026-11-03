# frozen_string_literal: true

email_catalog_permissions = %w[
  email_templates.access email_templates.create email_templates.update
  email_templates.publish email_templates.archive email_templates.preview
  email_templates.send_test email_templates.versions email_branding.manage
  email_settings.manage email_template_audits.view
]

email_catalog_permissions.each do |code|
  Permission.find_or_create_by!(code:) do |permission|
    permission.name = code.tr('._', ' ').titleize.first(80)
    permission.module_name = 'Communication'
    permission.description = "Email administration: #{code}"
    permission.status = :active
  end
end

email_catalog_content = {
  'user_invitation' => [
    ['Invitación para unirte a Delta POS', 'Activa tu acceso a la organización que te ha invitado.'],
    ['Invitation to join Delta POS', 'Activate your access to the organization that invited you.'],
    ['Delta POS 초대 안내', '초대한 조직에 참여하려면 계정을 활성화하세요.']
  ],
  'user_invitation_resend' => [
    ['Tu invitación se ha reenviado', 'Recibiste un nuevo enlace para activar tu acceso.'],
    ['Your invitation was resent', 'You have received a new link to activate your access.'],
    ['초대장을 다시 보냈습니다', '계정을 활성화할 수 있는 새 링크를 받았습니다.']
  ],
  'user_welcome' => [
    ['Bienvenido a Delta POS', 'Tu cuenta está lista para utilizar las herramientas de tu organización.'],
    ['Welcome to Delta POS', 'Your account is ready to use your organization tools.'],
    ['Delta POS에 오신 것을 환영합니다', '조직의 도구를 사용할 준비가 되었습니다.']
  ],
  'password_recovery' => [
    ['Recupera tu contraseña de Delta POS', 'Se solicitó un restablecimiento de contraseña.'],
    ['Reset your Delta POS password', 'A password reset has been requested.'],
    ['Delta POS 비밀번호 재설정', '비밀번호 재설정 요청이 접수되었습니다.']
  ],
  'password_changed' => [
    ['Tu contraseña se actualizó', 'La contraseña de tu cuenta se ha modificado correctamente.'],
    ['Your password was changed', 'Your account password has been updated successfully.'],
    ['비밀번호가 변경되었습니다', '계정 비밀번호가 성공적으로 변경되었습니다.']
  ],
  'account_suspended' => [
    ['Tu cuenta fue suspendida', 'El acceso a tu organización ha sido suspendido.'],
    ['Your account was suspended', 'Access to your organization has been suspended.'],
    ['계정이 일시 중지되었습니다', '조직에 대한 접근이 일시 중지되었습니다.']
  ],
  'account_reactivated' => [
    ['Tu cuenta fue reactivada', 'Tu acceso ha sido restablecido.'],
    ['Your account was reactivated', 'Your access has been restored.'],
    ['계정이 재활성화되었습니다', '접근 권한이 복구되었습니다.']
  ],
  'security_alert' => [
    ['Aviso de seguridad de Delta POS', 'Detectamos una actividad que requiere tu atención.'],
    ['Delta POS security alert', 'We detected activity that requires your attention.'],
    ['Delta POS 보안 알림', '확인이 필요한 활동이 감지되었습니다.']
  ],
  'email_changed' => [
    ['Se cambió tu correo electrónico', 'La dirección de correo electrónico de tu cuenta fue actualizada.'],
    ['Your email address was changed', 'Your account email address has been updated.'],
    ['이메일 주소가 변경되었습니다', '계정 이메일 주소가 업데이트되었습니다.']
  ]
}

email_catalog_locales = %w[es en ko]
email_catalog_content.each do |key, translations|
  email_catalog_locales.each_with_index do |locale, position|
    subject, message = translations.fetch(position)
    invitation = key.in?(%w[user_invitation user_invitation_resend])
    recipient_key = invitation ? 'invited_name' : 'recipient_name'
    logo_key = invitation ? 'logo_url' : 'platform_logo'
    action_url = key == 'password_recovery' ? 'recovery_url' : 'activation_url'
    action = invitation || key == 'password_recovery'
    action_link = action ? %(<p><a href="{{#{action_url}}}" style="color:#047857">Open Delta POS</a></p>) : ''
    html = <<~HTML
      <!doctype html>
      <html lang="#{locale}">
      <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
      <body style="margin:0;padding:24px;background:#f1f5f9;font-family:Arial,sans-serif;color:#0f172a">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          <tr><td align="center">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#fff">
              <tr><td style="padding:24px;background:#064e3b;color:#fff">
                <img src="{{#{logo_key}}}" width="44" alt="Delta POS" style="vertical-align:middle">
                <strong style="margin-left:12px;color:#fff">Delta POS</strong>
                <span style="float:right;color:#a7f3d0">{{organization_name}}</span>
              </td></tr>
              <tr><td style="padding:36px">
                <h1 style="font-size:24px">#{subject}</h1>
                <p>{{#{recipient_key}}}</p>
                <p>#{message}</p>
                #{action_link}
              </td></tr>
              <tr><td style="padding:18px;color:#64748b;background:#f8fafc">
                Delta POS · {{current_year}}
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML
    plain = "#{subject}\n\n{{#{recipient_key}}}\n#{message}\n"
    plain += "{{#{action_url}}}\n" if action

    template = EmailTemplate.find_or_create_by!(key:, locale:, organization_id: nil) do |record|
      record.name = subject
      record.category = 'security'
      record.status = 'published'
      record.subject = subject
      record.html_body = html
      record.text_body = plain
      record.enabled = true
    end
    next if template.published_version

    version = template.versions.find_or_create_by!(version_number: template.version) do |record|
      record.status = 'published'
      record.subject = template.subject
      record.html_body = template.html_body
      record.text_body = template.text_body
      content = [record.subject, record.html_body, record.text_body].join(' ')
      record.allowed_variables = content.scan(/\{\{([a-z][a-z0-9_]*)\}\}/).flatten.uniq
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
    content = [record.subject, record.html_body, record.text_body].join(' ')
    record.allowed_variables = content.scan(/\{\{([a-z][a-z0-9_]*)\}\}/).flatten.uniq
    record.published_at = Time.current
  end
  template.update!(published_version: version)
end
