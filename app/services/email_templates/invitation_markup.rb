# frozen_string_literal: true

module EmailTemplates
  # Table-based markup keeps invitation emails legible in common email clients.
  class InvitationMarkup
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
                      <img src="{{platform_logo}}" width="320" alt="#{copy.fetch(:brandAlt)}" style="display:block;width:320px;max-width:100%;height:auto;border:0;text-decoration:none;">
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
