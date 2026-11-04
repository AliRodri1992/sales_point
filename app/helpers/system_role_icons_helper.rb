# frozen_string_literal: true

module SystemRoleIconsHelper
  ROLE_ICONS = {
    'super_admin' => 'shield-crown',
    'administrator' => 'shield-check',
    'manager' => 'briefcase',
    'supervisor' => 'clipboard-document-list',
    'cashier' => 'calculator',
    'salesman' => 'tag',
    'inventory' => 'cube',
    'purchases' => 'shopping-cart',
    'finance' => 'banknotes',
    'auditor' => 'document-magnifying-glass',
    'support' => 'headset'
  }.freeze

  ROLE_TEXT_ICONS = [
    [/super.?admin|최고\s*관리자/i, 'shield-crown'],
    [/auditor|audit|감사/i, 'document-magnifying-glass'],
    [/cajer|\bcaja\b|cashier|cash register|캐셔|계산원/i, 'calculator'],
    [/inventari|inventory|warehouse|almac[eé]n|bodega|재고|창고/i, 'cube'],
    [/compra|purchas|procurement|adquisici|구매|조달/i, 'shopping-cart'],
    [/finanz|financ|contab|tesorer|accountant|재무|회계/i, 'banknotes'],
    [/vendedor|ventas|sales|comercial|판매|영업/i, 'tag'],
    [/supervis|jefe de turno|감독|책임자/i, 'clipboard-document-list'],
    [/gerent|gerencia|manager|direcci[oó]n|매니저|경영/i, 'briefcase'],
    [/soporte|support|t[eé]cnic|help.?desk|지원|기술/i, 'headset'],
    [/administrador|administrator|administraci[oó]n|관리자/i, 'shield-check']
  ].freeze

  def system_role_icon(system_role)
    role_text_icon(system_role.name) || ROLE_ICONS[system_role.code.to_s] ||
      role_text_icon(system_role.description) || 'identification'
  end

  private

  def role_text_icon(text)
    ROLE_TEXT_ICONS.find { |pattern, _| pattern.match?(text.to_s) }&.last
  end
end
