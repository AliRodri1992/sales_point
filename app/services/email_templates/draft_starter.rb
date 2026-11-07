# frozen_string_literal: true

module EmailTemplates
  # Responsive, email-client-safe first draft with the complete platform logo.
  # The recipient-specific text is editable before publication.
  class DraftStarter
    COPY = {
      'es' => {
        heading: 'Un mensaje de Delta POS',
        hello: 'Hola,',
        intro: 'Te compartimos un mensaje de {{organization_name}}.',
        footer: 'Este es un correo de Delta POS.'
      },
      'en' => {
        heading: 'A message from Delta POS',
        hello: 'Hello,',
        intro: 'Here is a message from {{organization_name}}.',
        footer: 'This is an email from Delta POS.'
      },
      'ko' => {
        heading: 'Delta POS에서 보낸 메시지',
        hello: '안녕하세요,',
        intro: '{{organization_name}}에서 메시지를 보냈습니다.',
        footer: '이 메일은 Delta POS에서 발송되었습니다.'
      }
    }.freeze

    HTML_TEMPLATE = <<~HTML
      <!doctype html>
      <html lang="__DELTA_LOCALE__">
      <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f1f5f9;width:100%;">
          <tr><td align="center" style="padding:32px 14px;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:600px;background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;">
              <tr><td style="padding:26px 32px;border-bottom:1px solid #e2e8f0;">
                <img src="{{platform_logo}}" alt="Delta POS" width="220" style="display:block;width:220px;max-width:100%;height:auto;border:0;">
              </td></tr>
              <tr><td style="padding:36px 32px;">
                <h1 style="margin:0 0 20px;font-size:25px;line-height:1.3;color:#064e3b;">__DELTA_HEADING__</h1>
                <p style="margin:0 0 12px;font-size:15px;line-height:1.7;color:#334155;">__DELTA_HELLO__ <strong>{{recipient_name}}</strong>.</p>
                <p style="margin:0;font-size:15px;line-height:1.7;color:#475569;">__DELTA_INTRO__</p>
              </td></tr>
              <tr><td style="padding:20px 32px;background:#f8fafc;border-top:1px solid #e2e8f0;">
                <p style="margin:0;font-size:12px;line-height:1.6;color:#64748b;">__DELTA_FOOTER__</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body>
      </html>
    HTML

    def self.html(locale)
      copy = COPY.fetch(locale.to_s, COPY.fetch('es'))
      HTML_TEMPLATE.gsub('__DELTA_LOCALE__', locale.to_s)
                   .gsub('__DELTA_HEADING__', copy.fetch(:heading))
                   .gsub('__DELTA_HELLO__', copy.fetch(:hello))
                   .gsub('__DELTA_INTRO__', copy.fetch(:intro))
                   .gsub('__DELTA_FOOTER__', copy.fetch(:footer))
    end

    def self.plain(locale)
      copy = COPY.fetch(locale.to_s, COPY.fetch('es'))
      <<~TEXT
        #{copy.fetch(:heading)}

        #{copy.fetch(:hello)} {{recipient_name}}.

        #{copy.fetch(:intro)}

        #{copy.fetch(:footer)}
      TEXT
    end
  end
end
