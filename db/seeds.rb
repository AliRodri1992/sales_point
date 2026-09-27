# frozen_string_literal: true

SYSTEM_ROLES = [
  {
    code: 'super_admin',
    name: 'Super administrador',
    description: 'Acceso total al sistema y a todas las sucursales.',
    role_type: :system
  },
  {
    code: 'administrator',
    name: 'Administrador',
    description: 'Administra la configuración y operación general del sistema.',
    role_type: :system
  },
  {
    code: 'accountant',
    name: 'Contador',
    description: 'Consulta y administra información fiscal y contable.',
    role_type: :system
  },
  {
    code: 'branch_manager',
    name: 'Gerente de sucursal',
    description: 'Administra la operación de una sucursal asignada.',
    role_type: :branch
  },
  {
    code: 'cashier',
    name: 'Cajero',
    description: 'Opera ventas, cobros y cortes de caja.',
    role_type: :branch
  },
  {
    code: 'inventory_manager',
    name: 'Encargado de inventario',
    description: 'Administra existencias, productos y movimientos de inventario.',
    role_type: :branch
  }
].freeze

def load_translations_from_file(file_path, locale_code)
  return unless File.exist?(file_path)

  content = YAML.safe_load_file(file_path)
  locale_hash = content[locale_code.to_s]
  language = Language.find_by(code: locale_code)
  return unless locale_hash && language

  flatten_hash(locale_hash, '').each do |key, value|
    persist_translation(key, value.to_s, locale_code, language) unless value.is_a?(Hash)
  end
end

def persist_translation(key, value, locale_code, language)
  if ActiveRecord::Base.connection.column_exists?(:translates, :language_id)
    Translate.find_or_create_by!(key: key, language: language) { |t| t.value = value }
  else
    # Fallback: use locale column if language_id doesn't exist yet
    Translate.find_or_create_by!(key: key, locale: locale_code) { |t| t.value = value }
  end
end

def flatten_hash(hash, prefix = '')
  result = {}
  hash.each do |key, value|
    current_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
    if value.is_a?(Hash)
      result.merge!(flatten_hash(value, current_key))
    else
      result[current_key] = value
    end
  end
  result
end

def create_sat_month(number)
  SatMonth.find_or_create_by!(code: format('%02d', number)) do |month|
    month.description = Date::MONTHNAMES[number]
    month.month_number = number
  end
end

# rubocop:disable Metrics/MethodLength
def seed_admin_user
  language = Language.find_by!(code: 'es')
  administrator_role = SystemRole.find_by!(code: 'administrator')

  user = User.find_or_initialize_by(email: 'administrador@delta.com')
  user.assign_attributes(
    username: 'administrador',
    password: 'administrador',
    password_confirmation: 'administrador',
    user_type: :employee,
    status: :active,
    theme: Theme::DEFAULT,
    language:
  )
  user.save!

  UserRole.find_or_create_by!(
    user:,
    system_role: administrator_role,
    branch: nil
  ) do |user_role|
    user_role.deleted_at = nil
  end
  # rubocop:enable Metrics/MethodLength
end

def seed_system_roles
  SYSTEM_ROLES.each do |role_attributes|
    SystemRole.find_or_initialize_by(code: role_attributes[:code]).tap do |role|
      role.assign_attributes(role_attributes)
      role.status = :active
      role.save!
    end
  end
end

# Create default languages
[
  { code: 'en', name: 'English', flag_iso: 'us', status: 'active' },
  { code: 'es', name: 'Español', flag_iso: 'mx', status: 'active' },
  { code: 'ko', name: '한국어', flag_iso: 'kr', status: 'active' }
].each do |lang_attrs|
  Language.find_or_create_by(code: lang_attrs[:code]) do |language|
    language.assign_attributes(lang_attrs)
  end
end

# Load all locale files
Rails.root.glob('config/locales/*.yml').each do |file|
  next if file.to_s.include?('devise.security_extension')

  filename = File.basename(file)
  case filename
  when 'en.yml', 'devise.en.yml' then load_translations_from_file(file, 'en')
  when 'es.yml', 'devise.es.yml' then load_translations_from_file(file, 'es')
  when 'ko.yml', 'devise.ko.yml' then load_translations_from_file(file, 'ko')
  end
end

(1..12).each do |i|
  create_sat_month(i)
end

seed_system_roles
seed_admin_user
