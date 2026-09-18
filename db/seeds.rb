# Load translations from YAML files into database
def load_translations_from_file(file_path, locale_code)
  return unless File.exist?(file_path)

  content = YAML.safe_load(File.read(file_path))
  locale_hash = content[locale_code.to_s]

  return unless locale_hash

  language = Language.find_by(code: locale_code)
  return unless language

  flatten_hash(locale_hash, '').each do |key, value|
    next if value.is_a?(Hash)

    # Check if language_id column exists (for backward compatibility)
    if ActiveRecord::Base.connection.column_exists?(:translates, :language_id)
      Translate.find_or_create_by!(key: key, language: language) do |t|
        t.value = value.to_s
      end
    else
      # Fallback: use locale column if language_id doesn't exist yet
      Translate.find_or_create_by!(key: key, locale: locale_code) do |t|
        t.value = value.to_s
      end
    end
  end
end

def flatten_hash(hash, prefix = "")
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
  when 'en.yml', 'devise.en.yml'
    load_translations_from_file(file, 'en')
  when 'es.yml', 'devise.es.yml'
    load_translations_from_file(file, 'es')
  when 'ko.yml', 'devise.ko.yml'
    load_translations_from_file(file, 'ko')
  else
    # type code here
  end
end

(1..12).each do |i|
  SatMonth.find_or_create_by(
    code: format('%02d', i)
  ) do |month|
    month.description = Date::MONTHNAMES[i]
    month.month_number = i
  end

  # Roles available to the authorization layer.
  [
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
  ].each do |role_attributes|
    SystemRole.find_or_initialize_by(code: role_attributes[:code]).tap do |role|
      role.assign_attributes(role_attributes)
      role.status = :active
      role.save!
    end
  end
end
