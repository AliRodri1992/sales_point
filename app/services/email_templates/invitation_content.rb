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
        invite: 'te invitó a colaborar en Delta POS. Para comenzar, confirma tu invitación y ' \
                'crea una contraseña personal.',
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
        invite: 'has invited you to work together in Delta POS. To get started, ' \
                'accept your invitation and create your personal password.',
        detailsLabel: 'ORGANIZATION',
        accountLabel: 'INVITED ACCOUNT',
        action: 'Create my password',
        guideTitle: 'What happens next?',
        guide: 'Open the secure link to choose your password and activate your account.',
        expiration: 'This personal link can only be used once and expires in',
        hours: 'hours.',
        backup: 'If the button does not work, copy this address into your browser:',
        warning: 'If you weren\'t expecting this invitation, you can ignore this message. ' \
                 'Do not share the link with anyone.',
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
      activation_url expiration_hours current_year primary_color secondary_color button_color footer_text
    ].freeze

    def self.build(locale)
      code = COPY.key?(locale.to_s) ? locale.to_s : 'es'
      copy = COPY.fetch(code)
      {
        subject: copy.fetch(:subject),
        preheader: copy.fetch(:preheader),
        html_body: InvitationMarkup.html(code, copy),
        text_body: InvitationMarkup.plain(copy),
        allowed_variables: VARIABLES
      }
    end

    def self.ensure_published!
      EmailTemplates::InvitationPublisher.ensure_published!
    end
  end
end
