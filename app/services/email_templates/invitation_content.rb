# frozen_string_literal: true

module EmailTemplates
  # The canonical, localized, responsive email for accepting a new account.
  # Built-in content is versioned; organization-specific versions are untouched.
  class InvitationContent
    COPY = {
      'es' => {
        subject: 'Invitación a {{organization_name}} · Delta POS',
        preheader: 'Te han invitado a unirte a {{organization_name}}. Crea tu contraseña para activar tu acceso.',
        eyebrow: 'INVITACIÓN DE ACCESO',
        title: 'Tu equipo te está esperando',
        hello: 'Hola,',
        invite: 'te invitó a colaborar en Delta POS. Para comenzar, confirma tu invitación y crea una contraseña personal.',
        detailsLabel: 'ORGANIZACIÓN',
        accountLabel: 'CUENTA INVITADA',
        action: 'Crear mi contraseña',
        guideTitle: '¿Qué pasará después?',
        guide: 'Al abrir el enlace podrás establecer tu contraseña y activar tu cuenta de forma segura.',
        expiration: 'Este enlace es personal, solo puede utilizarse una vez y vence en',
        hours: 'horas.',
        backup: 'Si el botón no funciona, copia y abre esta dirección en tu navegador:',
        warning: 'Si no reconoces esta invitación, puedes ignorar este correo. No compartas el enlace con nadie.',
        footer: 'Correo automático de seguridad. No es necesario responder a este mensaje.',
        brandAlt: 'Delta POS — logotipo completo'
      },
      'en' => {
        subject: 'Invitation to {{organization_name}} · Delta POS',
        preheader: 'You\'ve been invited to {{organization_name}}. Create your password to activate access.',
        eyebrow: 'ACCOUNT INVITATION',
        title: 'Your team is waiting for you',
        hello: 'Hello,',
        invite: 'has invited you to work together in Delta POS. To get started, accept your invitation and create your personal password.',
        detailsLabel: 'ORGANIZATION',
        accountLabel: 'INVITED ACCOUNT',
        action: 'Create my password',
        guideTitle: 'What happens next?',
        guide: 'Open the secure link to choose your password and activate your account.',
        expiration: 'This personal link can only be used once and expires in',
        hours: 'hours.',
        backup: 'If the button does not work, copy this address into your browser:',
        warning: 'If you weren\'t expecting this invitation, you can ignore this message. Do not share the link with anyone.',
        footer: 'Automated security email. No reply is needed.',
        brandAlt: 'Delta POS — full logo'
      },
      'ko' => {
        subject: '{{organization_name}}의 Delta POS 초대',
        preheader: '{{organization_name}}에서 초대했습니다. 비밀번호를 만들어 계정을 활성화하세요.',
        eyebrow: '계정 초대',
        title: '팀에서 기다리고 있습니다',
        hello: '안녕하세요,',
        invite: '에서 Delta POS 협업에 초대했습니다. 시작하려면 초대를 수락하고 개인 비밀번호를 만들어 주세요.',
        detailsLabel: '조직',
        accountLabel: '초대받은 계정',
        action: '비밀번호 만들기',
        guideTitle: '다음 단계',
        guide: '보안 링크를 열어 비밀번호를 설정하면 계정을 안전하게 활성화할 수 있습니다.',
        expiration: '이 개인 링크는 한 번만 사용할 수 있으며 만료까지 남은 시간은',
        hours: '시간입니다.',
        backup: '버튼이 작동하지 않으면 다음 주소를 브라우저에 복사해 여세요:',
        warning: '초대를 요청한 적이 없다면 이 메일을 무시하세요. 링크를 다른 사람에게 공유하지 마세요.',
        footer: '이 메일은 자동 발송된 보안 알림입니다. 회신할 필요가 없습니다.',
        brandAlt: 'Delta POS 전체 로고'
      }
    }.freeze

    VARIABLES = %w[
      platform_logo invited_name recipient_email organization_name
      activation_url expiration_hours current_year
    ].freeze

    def self.build(locale)
      code = COPY.key?(locale.to_s) ? locale.to_s : 'es'
      copy = COPY.fetch(code)
      {
        subject: copy.fetch(:subject),
        html_body: html(code, copy),
        text_body: plain(copy),
        allowed_variables: VARIABLES
      }
    end

    def self.ensure_published!
      COPY.each_key { |locale| ensure_locale!(locale) }
    end

    def self.ensure_locale!(locale)
      data = build(locale)
      template = EmailTemplate.global.find_or_initialize_by(key: 'user_invitation', locale:)
      unless template.persisted?
        template.assign_attributes(
          name: 'User invitation', category: 'security', status: 'draft', enabled: false,
          subject: data.fetch(:subject), html_body: data.fetch(:html_body),
          text_body: data.fetch(:text_body)
        )
        template.save!
      end

      template.with_lock do
        if template.published_version
          next unless stock_legacy?(template)
        elsif template.versions.exists? && template.status != 'draft'
          next
        end

        draft = template.new_draft!(actor: nil)
        draft.update!(
          subject: data.fetch(:subject), html_body: data.fetch(:html_body),
          text_body: data.fetch(:text_body),
          allowed_variables: data.fetch(:allowed_variables)
        )
        draft.publish!(actor: nil)
      end
      template
    end

    def self.stock_legacy?(template)
      published = template.published_version
      return false unless published&.version_number == 1
      return false unless template.versions.count == 1

      signature = {
        'es' => ['INVITACIÓN A TU EQUIPO', 'Invitación para unirte a Delta POS'],
        'en' => ['Invitation to join Delta POS'],
        'ko' => ['Delta POS 초대 안내']
      }.fetch(template.locale, [])
      signature.any? { |text| published.html_body.include?(text) } &&
        published.html_body.include?('width="44"') ||
        (template.locale == 'es' && published.html_body.include?('INVITACIÓN A TU EQUIPO') &&
         published.html_body.include?('width="48"'))
    end

    def self.html(locale, copy)
      <<~HTML
        <!doctype html>
        <html lang="#{locale}">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body style="margin:0;padding:0;background-color:#f2f6f5;color:#0f172a;font-family:Arial,Helvetica,sans-serif;">
          <div style="display:none;font-size:1px;color:#f2f6f5;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">#{copy.fetch(:preheader)}</div>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;background-color:#f2f6f5;">
            <tr>
              <td align="center" style="padding:32px 12px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;background-color:#ffffff;border:1px solid #dde8e5;border-radius:16px;">
                  <tr>
                    <td style="padding:27px 36px 24px;border-bottom:1px solid #e5eeea;background-color:#ffffff;">
                      <img src="{{platform_logo}}" width="222" alt="#{copy.fetch(:brandAlt)}" style="display:block;width:222px;max-width:100%;height:auto;border:0;text-decoration:none;">
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:38px 36px 18px;">
                      <p style="margin:0 0 14px;color:#047857;font-size:11px;font-weight:700;letter-spacing:1.6px;line-height:1.5;">#{copy.fetch(:eyebrow)}</p>
                      <h1 style="margin:0 0 20px;color:#0f172a;font-size:29px;font-weight:700;line-height:1.25;">#{copy.fetch(:title)}</h1>
                      <p style="margin:0 0 12px;color:#334155;font-size:15px;line-height:1.8;">#{copy.fetch(:hello)} <strong>{{invited_name}}</strong>.</p>
                      <p style="margin:0 0 24px;color:#475569;font-size:15px;line-height:1.8;"><strong>{{organization_name}}</strong> #{copy.fetch(:invite)}</p>
                      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;border:1px solid #d7e9e1;background-color:#f4fbf7;border-radius:10px;">
                        <tr><td style="padding:17px 20px 7px;color:#047857;font-size:11px;font-weight:700;letter-spacing:1px;">#{copy.fetch(:detailsLabel)}</td></tr>
                        <tr><td style="padding:0 20px 15px;color:#123c30;font-size:16px;font-weight:700;line-height:1.5;">{{organization_name}}</td></tr>
                        <tr><td style="padding:0 20px 6px;color:#64748b;font-size:11px;font-weight:700;letter-spacing:1px;">#{copy.fetch(:accountLabel)}</td></tr>
                        <tr><td style="padding:0 20px 18px;color:#334155;font-size:14px;line-height:1.6;">{{recipient_email}}</td></tr>
                      </table>
                      <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:28px 0 23px;">
                        <tr><td align="center" bgcolor="#047857" style="background-color:#047857;border-radius:10px;">
                          <a href="{{activation_url}}" style="display:inline-block;padding:16px 28px;color:#ffffff;background-color:#047857;border-radius:10px;font-size:15px;font-weight:700;line-height:1.3;text-align:center;text-decoration:none;">#{copy.fetch(:action)}</a>
                        </td></tr>
                      </table>
                      <p style="margin:0 0 9px;font-size:14px;font-weight:700;color:#0f172a;">#{copy.fetch(:guideTitle)}</p>
                      <p style="margin:0 0 18px;color:#475569;font-size:13px;line-height:1.75;">#{copy.fetch(:guide)}</p>
                      <p style="margin:0 0 22px;color:#7c4b13;background-color:#fffaf0;border:1px solid #f1e2c5;padding:13px 16px;border-radius:8px;font-size:13px;line-height:1.7;">#{copy.fetch(:expiration)} <strong>{{expiration_hours}} #{copy.fetch(:hours)}</strong></p>
                      <p style="margin:0 0 8px;color:#64748b;font-size:12px;line-height:1.65;">#{copy.fetch(:backup)}</p>
                      <p style="margin:0 0 6px;font-size:12px;line-height:1.7;word-break:break-all;overflow-wrap:anywhere;">
                        <a href="{{activation_url}}" style="color:#047857;text-decoration:underline;word-break:break-all;">{{activation_url}}</a>
                      </p>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:20px 36px;background-color:#f8faf9;border-top:1px solid #e5eeea;">
                      <p style="margin:0 0 13px;color:#475569;font-size:12px;line-height:1.75;">#{copy.fetch(:warning)}</p>
                      <p style="margin:0;color:#64748b;font-size:11px;line-height:1.7;">#{copy.fetch(:footer)}</p>
                      <p style="margin:12px 0 0;color:#94a3b8;font-size:11px;line-height:1.6;">© {{current_year}} Delta POS</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </body>
        </html>
      HTML
    end

    def self.plain(copy)
      <<~TEXT
        #{copy.fetch(:title)}

        #{copy.fetch(:hello)} {{invited_name}}.
        {{organization_name}} #{copy.fetch(:invite)}

        #{copy.fetch(:detailsLabel)}: {{organization_name}}
        #{copy.fetch(:accountLabel)}: {{recipient_email}}

        #{copy.fetch(:action)}: {{activation_url}}

        #{copy.fetch(:guideTitle)}
        #{copy.fetch(:guide)}

        #{copy.fetch(:expiration)} {{expiration_hours}} #{copy.fetch(:hours)}
        #{copy.fetch(:backup)} {{activation_url}}

        #{copy.fetch(:warning)}
        #{copy.fetch(:footer)}
        © {{current_year}} Delta POS
      TEXT
    end
  end
end
