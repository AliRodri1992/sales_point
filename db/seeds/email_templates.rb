# frozen_string_literal: true

EmailTemplate.find_or_create_by!(key: 'user_invitation', locale: 'es') do |template|
  template.name = 'User invitation'
  template.subject = 'Te invitaron a Delta POS · {{organization_name}}'
  template.html_body = <<~HTML
    <!doctype html>
    <html lang="es">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    </head>
    <body style="margin:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
    <tr>
    <td align="center" style="padding:40px 16px">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#fff;border:1px solid #e2e8f0;border-radius:18px">
    <tr>
    <td style="background:#064e3b;padding:30px 36px">
    <img src="{{logo_url}}" width="48" alt="Delta POS" style="display:block;border:0">
    <div style="color:#fff;font-size:24px;font-weight:bold;margin-top:14px">Delta POS</div>
    <div style="color:#a7f3d0;font-size:13px">Gestión inteligente para tu negocio</div>
    </td>
    </tr>
    <tr>
    <td style="padding:36px">
    <p style="color:#047857;font-size:12px;font-weight:bold;letter-spacing:2px">INVITACIÓN A TU EQUIPO</p>
    <h1 style="font-size:27px">¡Te damos la bienvenida!</h1>
    <p style="font-size:15px;line-height:1.8;color:#475569">Hola, <strong>{{invited_name}}</strong>. <strong>{{organization_name}}</strong> te ha invitado a colaborar en Delta POS. Activa tu cuenta y establece tu propia contraseña.</p>
    <p style="padding:22px 0;text-align:center">
    <a href="{{activation_url}}" style="display:inline-block;background:#047857;color:#fff;text-decoration:none;padding:16px 30px;border-radius:12px;font-weight:bold">Activar mi cuenta</a>
    </p>
    <p style="font-size:13px;line-height:1.7;color:#64748b">Este enlace es personal, de un solo uso y vence en {{expiration_hours}} horas. No compartas este correo.</p>
    <p style="font-size:12px;color:#64748b">Si el botón no funciona, abre:<br>
    <a href="{{activation_url}}" style="color:#047857;word-break:break-all">{{activation_url}}</a>
    </p>
    <hr style="border:0;border-top:1px solid #e2e8f0;margin:25px 0">
    <p style="font-size:12px;color:#64748b">Si no esperabas esta invitación, ignora el mensaje. Tu cuenta seguirá sin activarse.</p>
    </td>
    </tr>
    <tr>
    <td style="background:#f8fafc;padding:20px;text-align:center;color:#94a3b8;font-size:12px">© {{current_year}} Delta POS · Mensaje automático</td>
    </tr>
    </table>
    </td>
    </tr>
    </table>
    </body>
    </html>
  HTML
  template.text_body = <<~TEXT
    Hola, {{invited_name}}:
    {{organization_name}} te ha invitado a utilizar Delta POS.
    Activa tu cuenta y establece tu contraseña en: {{activation_url}}
    El enlace vence en {{expiration_hours}} horas y es de un solo uso.
    Si no esperabas esta invitación, ignora este correo.
  TEXT
end
