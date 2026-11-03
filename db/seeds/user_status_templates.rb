# frozen_string_literal: true

EmailTemplate.find_or_create_by!(key: 'user_status_changed', locale: 'es') do |template|
  template.subject = "Actualización de acceso · Delta POS"
  template.html_body = <<~HTML
    <!doctype html>
    <html lang="es">
    <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:42px 14px">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:580px;border-radius:18px;background:#ffffff;border:1px solid #e2e8f0">
    <tr><td style="background:#064e3b;padding:28px 36px"><img src="{{logo_url}}" alt="Delta POS" width="46" height="46" style="border:0;display:block"><div style="margin-top:12px;color:#fff;font-size:22px;font-weight:bold">Delta POS</div></td></tr>
    <tr><td style="padding:36px"><h1 style="margin:0 0 16px;font-size:25px;line-height:1.35">Actualización de tu cuenta</h1>
    <p style="font-size:15px;color:#475569;line-height:1.8">Hola, <strong>{{recipient_name}}</strong>.</p>
    <p style="font-size:15px;color:#475569;line-height:1.8">Se ha actualizado el estatus de tu cuenta en la organización indicada.</p>
    <div style="margin:24px 0;padding:20px;border-radius:12px;border:1px solid #d1fae5;background:#ecfdf5">
    <div style="font-size:13px;color:#047857;font-weight:bold">{{organization_name}}</div>
    <div style="margin-top:10px;font-size:12px;color:#64748b">Estatus actual</div>
    <div style="margin-top:4px;font-size:18px;font-weight:bold;color:#065f46">{{status_label}}</div>
    </div>
    <p style="font-size:13px;color:#64748b;line-height:1.75">Si no reconoces este cambio, comunícate con el administrador de tu organización.</p></td></tr>
    <tr><td style="background:#f8fafc;padding:20px 36px;text-align:center;font-size:12px;color:#94a3b8">Este es un mensaje de seguridad automático de Delta POS.</td></tr>
    </table></td></tr></table></body></html>
  HTML
  template.text_body = <<~TEXT
    Hola, {{recipient_name}}.
    
    Se ha actualizado el estatus de tu cuenta en la organización indicada.
    
    {{organization_name}} — Estatus actual: {{status_label}}
    
    Si no reconoces este cambio, comunícate con el administrador de tu organización.
    
    Este es un mensaje de seguridad automático de Delta POS.
  TEXT
end

EmailTemplate.find_or_create_by!(key: 'user_status_changed', locale: 'en') do |template|
  template.subject = "Account access update · Delta POS"
  template.html_body = <<~HTML
    <!doctype html>
    <html lang="en">
    <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:42px 14px">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:580px;border-radius:18px;background:#ffffff;border:1px solid #e2e8f0">
    <tr><td style="background:#064e3b;padding:28px 36px"><img src="{{logo_url}}" alt="Delta POS" width="46" height="46" style="border:0;display:block"><div style="margin-top:12px;color:#fff;font-size:22px;font-weight:bold">Delta POS</div></td></tr>
    <tr><td style="padding:36px"><h1 style="margin:0 0 16px;font-size:25px;line-height:1.35">Your account status has changed</h1>
    <p style="font-size:15px;color:#475569;line-height:1.8">Hello, <strong>{{recipient_name}}</strong>.</p>
    <p style="font-size:15px;color:#475569;line-height:1.8">Your account status has been updated for the organization below.</p>
    <div style="margin:24px 0;padding:20px;border-radius:12px;border:1px solid #d1fae5;background:#ecfdf5">
    <div style="font-size:13px;color:#047857;font-weight:bold">{{organization_name}}</div>
    <div style="margin-top:10px;font-size:12px;color:#64748b">Current status</div>
    <div style="margin-top:4px;font-size:18px;font-weight:bold;color:#065f46">{{status_label}}</div>
    </div>
    <p style="font-size:13px;color:#64748b;line-height:1.75">If you do not recognize this change, contact your organization administrator.</p></td></tr>
    <tr><td style="background:#f8fafc;padding:20px 36px;text-align:center;font-size:12px;color:#94a3b8">This is an automated Delta POS security message.</td></tr>
    </table></td></tr></table></body></html>
  HTML
  template.text_body = <<~TEXT
    Hello, {{recipient_name}}.
    
    Your account status has been updated for the organization below.
    
    {{organization_name}} — Current status: {{status_label}}
    
    If you do not recognize this change, contact your organization administrator.
    
    This is an automated Delta POS security message.
  TEXT
end

EmailTemplate.find_or_create_by!(key: 'user_status_changed', locale: 'ko') do |template|
  template.subject = "계정 접근 상태 변경 · Delta POS"
  template.html_body = <<~HTML
    <!doctype html>
    <html lang="ko">
    <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:42px 14px">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:580px;border-radius:18px;background:#ffffff;border:1px solid #e2e8f0">
    <tr><td style="background:#064e3b;padding:28px 36px"><img src="{{logo_url}}" alt="Delta POS" width="46" height="46" style="border:0;display:block"><div style="margin-top:12px;color:#fff;font-size:22px;font-weight:bold">Delta POS</div></td></tr>
    <tr><td style="padding:36px"><h1 style="margin:0 0 16px;font-size:25px;line-height:1.35">계정 상태가 변경되었습니다</h1>
    <p style="font-size:15px;color:#475569;line-height:1.8">안녕하세요, <strong>{{recipient_name}}</strong>.</p>
    <p style="font-size:15px;color:#475569;line-height:1.8">아래 조직의 계정 상태가 변경되었습니다.</p>
    <div style="margin:24px 0;padding:20px;border-radius:12px;border:1px solid #d1fae5;background:#ecfdf5">
    <div style="font-size:13px;color:#047857;font-weight:bold">{{organization_name}}</div>
    <div style="margin-top:10px;font-size:12px;color:#64748b">현재 상태</div>
    <div style="margin-top:4px;font-size:18px;font-weight:bold;color:#065f46">{{status_label}}</div>
    </div>
    <p style="font-size:13px;color:#64748b;line-height:1.75">변경 사항을 확인할 수 없다면 조직 관리자에게 문의하세요.</p></td></tr>
    <tr><td style="background:#f8fafc;padding:20px 36px;text-align:center;font-size:12px;color:#94a3b8">Delta POS에서 발송한 자동 보안 안내입니다.</td></tr>
    </table></td></tr></table></body></html>
  HTML
  template.text_body = <<~TEXT
    안녕하세요, {{recipient_name}}.
    
    아래 조직의 계정 상태가 변경되었습니다.
    
    {{organization_name}} — 현재 상태: {{status_label}}
    
    변경 사항을 확인할 수 없다면 조직 관리자에게 문의하세요.
    
    Delta POS에서 발송한 자동 보안 안내입니다.
  TEXT
end
