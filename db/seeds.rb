# frozen_string_literal: true

require_relative 'seeds/seed_console'

SeedConsole.start_run!

SYSTEM_ROLES = [
  {
    code: 'super_admin',
    name: 'Superadministrador',
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
    code: 'manager',
    name: 'Gerente',
    description: 'Administra operaciones y sucursales asignadas.',
    role_type: :system
  },
  {
    code: 'supervisor',
    name: 'Supervisor',
    description: 'Supervisa equipos de operación y producción.',
    role_type: :system
  },
  {
    code: 'cashier',
    name: 'Cajero',
    description: 'Opera la caja, cobros y cortes de caja.',
    role_type: :system
  },
  {
    code: 'salesman',
    name: 'Vendedor',
    description: 'Gestiona carteras, cotizaciones y ventas.',
    role_type: :system
  },
  {
    code: 'inventory',
    name: 'Inventarios',
    description: 'Administra existencias, productos y movimientos de inventario.',
    role_type: :system
  },
  {
    code: 'purchases',
    name: 'Compras',
    description: 'Administra órdenes de compra y proveedores.',
    role_type: :system
  },
  {
    code: 'finance',
    name: 'Finanzas',
    description: 'Consulta y administra información fiscal y financiera.',
    role_type: :system
  },
  {
    code: 'auditor',
    name: 'Auditor',
    description: 'Audita registros, movimientos y conciliaciones.',
    role_type: :system
  },
  {
    code: 'support',
    name: 'Soporte',
    description: 'Soporte técnico y resolución de incidencias.',
    role_type: :system
  }
].freeze

DEFAULT_PERMISSIONS = [
  {
    code: 'dashboard.access',
    name: 'Acceso al dashboard',
    module_name: 'Dashboard',
    description: 'Permite acceder al panel principal.'
  },
  {
    code: 'sales.access',
    name: 'Acceso a ventas',
    module_name: 'Ventas',
    description: 'Permite acceder al módulo de ventas.'
  },
  {
    code: 'cash_register.access',
    name: 'Acceso a caja',
    module_name: 'Caja',
    description: 'Permite acceder al módulo de caja.'
  },
  {
    code: 'inventory.access',
    name: 'Acceso a inventario',
    module_name: 'Inventario',
    description: 'Permite acceder al módulo de inventario.'
  },
  {
    code: 'customers.access',
    name: 'Acceso a clientes',
    module_name: 'Clientes',
    description: 'Permite acceder al módulo de clientes.'
  },
  {
    code: 'suppliers.access',
    name: 'Acceso a proveedores',
    module_name: 'Proveedores',
    description: 'Permite acceder al módulo de proveedores.'
  },
  {
    code: 'employees.access',
    name: 'Acceso a empleados',
    module_name: 'Empleados',
    description: 'Permite acceder al módulo de empleados.'
  },
  {
    code: 'reports.access',
    name: 'Acceso a reportes',
    module_name: 'Reportes',
    description: 'Permite acceder al módulo de reportes.'
  },
  {
    code: 'products.access',
    name: 'Acceso a productos',
    module_name: 'Productos',
    description: 'Permite acceder al catálogo de productos.'
  },
  {
    code: 'categories.access',
    name: 'Acceso a categorías',
    module_name: 'Categorías',
    description: 'Permite acceder al catálogo de categorías.'
  },
  {
    code: 'branches.access',
    name: 'Acceso a sucursales',
    module_name: 'Sucursales',
    description: 'Permite administrar las sucursales.'
  },
  {
    code: 'languages.access',
    name: 'Acceso a idiomas',
    module_name: 'Idiomas',
    description: 'Permite administrar los idiomas disponibles.'
  },
  { code: 'roles.access', name: 'Acceso a roles', module_name: 'Roles',
    description: 'Permite administrar roles y sus permisos.' }
].freeze

def load_translations_from_file(file_path, locale_code)
  return unless File.exist?(file_path)

  content = YAML.safe_load_file(file_path)
  locale_hash = content[locale_code.to_s]
  language = Language.find_by(code: locale_code)
  return unless locale_hash && language

  flatten_hash(locale_hash, '').each do |key, value|
    next if value.is_a?(Hash)
    next if value.blank? || value.to_s.strip.empty?

    persist_translation(key, value.to_s, locale_code, language)
  end
end

def persist_translation(key, value, locale_code, language)
  translation = Translate.find_by(key: key, language: language)
  if translation
    translation.update!(value: value) if translation.value != value
  elsif ActiveRecord::Base.connection.column_exists?(:translates, :language_id)
    Translate.create!(key: key, language: language, value: value)
  else
    # Fallback: use locale column if language_id doesn't exist yet
    Translate.create!(key: key, locale: locale_code, value: value)
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

def seed_permissions
  DEFAULT_PERMISSIONS.each do |permission_attributes|
    Permission.find_or_initialize_by(code: permission_attributes[:code]).tap do |permission|
      permission.assign_attributes(permission_attributes)
      permission.status = :active
      permission.save!
    end
  end
end

def assign_default_role_permissions
  %w[super_admin administrator].each do |role_code|
    role = SystemRole.available.find_by!(code: role_code)
    AdministratorPermissionProvisioner.call(role:)
  end
end

def seed_admin_user
  language = Language.find_by!(code: 'es')
  administrator_role = SystemRole.find_by!(code: 'administrator')
  user = User.find_or_initialize_by(email: 'administrador@delta.com')
  assign_admin_user_attributes(user, language)
  user.save!
  assign_admin_role(user, administrator_role)
end

def assign_admin_user_attributes(user, language)
  user.assign_attributes(
    username: 'administrador',
    password: 'administrador',
    password_confirmation: 'administrador',
    user_type: :employee,
    status: :active,
    theme: Theme::DEFAULT,
    language:
  )
end

def assign_admin_role(user, administrator_role)
  UserRole.find_or_create_by!(user:, system_role: administrator_role, branch: nil) do |user_role|
    user_role.deleted_at = nil
  end
end

USER_SEED_ROLES = %w[manager supervisor cashier salesman inventory purchases finance auditor support].freeze

def seed_users(count = 15)
  roles = SystemRole.where(code: USER_SEED_ROLES)
  language = Language.find_by!(code: 'es')

  count.times do |index|
    user = User.find_or_initialize_by(email: "user#{index + 1}@delta.com")
    assign_user_attributes(user, language, index)
    user.save!
    UserRole.find_or_create_by!(user:, system_role: roles.sample, branch: nil)
  end
end

def assign_user_attributes(user, language, index)
  user.assign_attributes(
    username: "user#{index + 1}",
    password: 'password123',
    password_confirmation: 'password123',
    user_type: :employee,
    status: :active,
    theme: Theme::DEFAULT,
    language:
  )
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

SeedConsole.track('Idiomas', Language) do
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
end

SeedConsole.track('Traducciones', Translate) do
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
end

SeedConsole.track('Meses SAT', SatMonth) do
  (1..12).each do |i|
    create_sat_month(i)
  end
end

require_relative 'seeds/currencies'
require_relative 'seeds/countries'
SeedConsole.track('Monedas', Currency) { CurrencySeeds.seed! }
SeedConsole.track('Países', Country) { CountrySeeds.seed! }
SeedConsole.report('Monedas por país', CountryCurrency)

SeedConsole.track('Roles', SystemRole) { seed_system_roles }
SeedConsole.track('Permisos', Permission) { seed_permissions }
SeedConsole.track('Asignación de permisos') { assign_default_role_permissions }
SeedConsole.track('Usuario administrador', User) { seed_admin_user }
SeedConsole.track('Usuarios de ejemplo', User) { seed_users }

require_relative 'seeds/supplier_examples'
SeedConsole.track('Organización Delta POS', Organization) do
  SupplierExamples.seed!
end
SeedConsole.report('Proveedores', Supplier)
SeedConsole.report('Contactos', Contact)
SeedConsole.report('Membresías', OrganizationMembership)

# Deterministic examples avoid Faker collisions and invalid phone/address data.
SeedConsole.track('Clientes', Client) do
  20.times do |index|
    number = index + 1
    code = format('CLI%04d', number)
    next if Client.exists?(code:)

    Client.create!(
      code:,
      name: "Cliente de ejemplo #{number}",
      email: "cliente#{number}@example.com",
      phone: format('551234%04d', number),
      rfc: format('CDE260101%03d', number),
      postal_code: '06000',
      credit_limit: number * 1000,
      notes: "Cliente de demostración #{number}.",
      status: (number % 5).zero? ? :inactive : :active
    )
  end
end

SeedConsole.track('Categorías', Category) do
  15.times do |index|
    number = index + 1
    code = format('cat%04d', number)
    next if Category.exists?(code:)

    Category.create!(
      code:,
      name: "Categoría #{number}",
      description: "Categoría de ejemplo #{number} para Delta POS.",
      status: (number % 5).zero? ? :inactive : :active
    )
  end
end

SeedConsole.track('Productos', Product) do
  categories = Category.not_deleted.order(:id).to_a
  raise 'No hay categorías disponibles para crear productos' if categories.empty?

  15.times do |index|
    number = index + 1
    code = format('PROD%04d', number)
    next if Product.exists?(code:)

    Product.create!(
      code:,
      name: "Producto de ejemplo #{number}",
      description: "Producto de demostración #{number} para Delta POS.",
      price: number * 100,
      cost: number * 60,
      stock: 100 + number,
      min_stock: 5,
      max_stock: 300,
      sku: format('SKU-DELTA-%04d', number),
      barcode: format('75000000%05d', number),
      category: categories[index % categories.length],
      status: (number % 5).zero? ? :inactive : :active
    )
  end
end

SeedConsole.track('Sucursales', Branch) do
  organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)

  15.times do |index|
    number = index + 1
    name = format('Sucursal Delta %02d', number)
    next if Branch.exists?(organization:, name:)

    Branch.create!(
      organization:,
      name:,
      phone: format('551234%04d', 100 + number),
      status: number % 5 != 0,
      address_attributes: {
        street: 'Avenida Insurgentes',
        exterior_number: number.to_s,
        neighborhood: 'Centro',
        city: 'Ciudad de México',
        state: 'Ciudad de México',
        country: 'México',
        postal_code: '06000'
      }
    )
  end
end

SeedConsole.report('Direcciones', Address)
SeedConsole.finish_run!
