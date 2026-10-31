# frozen_string_literal: true

require_relative 'seeds/seed_console'

SeedConsole.start_run!

unless defined?(SYSTEM_ROLES)
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
end

unless defined?(DEFAULT_PERMISSIONS)
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
      code: 'suppliers.view',
      name: 'View suppliers',
      module_name: 'Proveedores',
      description: 'View suppliers.'
    },
    {
      code: 'suppliers.create',
      name: 'Create suppliers',
      module_name: 'Proveedores',
      description: 'Create suppliers.'
    },
    {
      code: 'suppliers.update',
      name: 'Update suppliers',
      module_name: 'Proveedores',
      description: 'Update suppliers.'
    },
    {
      code: 'suppliers.destroy',
      name: 'Delete suppliers',
      module_name: 'Proveedores',
      description: 'Delete suppliers.'
    },
    {
      code: 'suppliers.export',
      name: 'Export suppliers',
      module_name: 'Proveedores',
      description: 'Export suppliers.'
    },
    {
      code: 'suppliers.contacts.view',
      name: 'View supplier contacts',
      module_name: 'Proveedores',
      description: 'View supplier contacts.'
    },
    {
      code: 'suppliers.contacts.manage',
      name: 'Manage supplier contacts',
      module_name: 'Proveedores',
      description: 'Manage supplier contacts.'
    },
    {
      code: 'suppliers.addresses.view',
      name: 'View supplier addresses',
      module_name: 'Proveedores',
      description: 'View supplier addresses.'
    },
    {
      code: 'suppliers.addresses.manage',
      name: 'Manage supplier addresses',
      module_name: 'Proveedores',
      description: 'Manage supplier addresses.'
    },
    {
      code: 'suppliers.schedules.view',
      name: 'View supplier schedules',
      module_name: 'Proveedores',
      description: 'View supplier schedules.'
    },
    {
      code: 'suppliers.schedules.manage',
      name: 'Manage supplier schedules',
      module_name: 'Proveedores',
      description: 'Manage supplier schedules.'
    },
    {
      code: 'suppliers.documents.view',
      name: 'View supplier documents',
      module_name: 'Proveedores',
      description: 'View supplier documents.'
    },
    {
      code: 'suppliers.documents.manage',
      name: 'Manage supplier documents',
      module_name: 'Proveedores',
      description: 'Manage supplier documents.'
    },
    {
      code: 'suppliers.fiscal.view',
      name: 'View supplier fiscal information',
      module_name: 'Proveedores',
      description: 'View supplier fiscal information.'
    },
    {
      code: 'suppliers.fiscal.manage',
      name: 'Manage supplier fiscal information',
      module_name: 'Proveedores',
      description: 'Manage supplier fiscal information.'
    },
    {
      code: 'suppliers.commercial.view',
      name: 'View supplier commercial data',
      module_name: 'Proveedores',
      description: 'View supplier commercial data.'
    },
    {
      code: 'suppliers.commercial.manage',
      name: 'Manage supplier commercial data',
      module_name: 'Proveedores',
      description: 'Manage supplier commercial data.'
    },
    { code: 'suppliers.products.view', name: 'Ver productos de proveedores',
      module_name: 'Proveedores', description: 'Consulta ofertas y precios por proveedor.' },
    { code: 'suppliers.products.manage', name: 'Administrar productos de proveedores',
      module_name: 'Proveedores', description: 'Edita ofertas de compra y presentaciones.' },
    {
      code: 'purchases.view',
      name: 'View purchases',
      module_name: 'Compras',
      description: 'View purchases within the current organization.'
    },
    {
      code: 'purchases.create',
      name: 'Create purchase documents',
      module_name: 'Compras',
      description: 'Create purchase documents within the current organization.'
    },
    {
      code: 'purchases.approve',
      name: 'Approve purchases',
      module_name: 'Compras',
      description: 'Approve purchases within the current organization.'
    },
    {
      code: 'purchases.receive',
      name: 'Receive purchased merchandise',
      module_name: 'Compras',
      description: 'Receive purchased merchandise within the current organization.'
    },
    {
      code: 'purchases.returns',
      name: 'Process supplier returns',
      module_name: 'Compras',
      description: 'Process supplier returns within the current organization.'
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
      description: 'Permite administrar roles y sus permisos.' },
    { code: 'accounts_payable.view', name: 'View accounts payable', module_name: 'Cuentas por pagar',
      description: 'View vendor invoices, outstanding balances and reconciliations.' },
    { code: 'accounts_payable.manage', name: 'Manage invoices', module_name: 'Cuentas por pagar',
      description: 'Create and edit vendor invoices, payments and credit notes.' },
    { code: 'accounts_payable.approve', name: 'Approve invoices and credits', module_name: 'Cuentas por pagar',
      description: 'Post and cancel vendor invoices and credit notes.' },
    { code: 'accounts_payable.pay', name: 'Apply and reverse payments', module_name: 'Cuentas por pagar',
      description: 'Post, allocate and reverse financial settlements.' },
    { code: 'accounts_payable.banks.view', name: 'View vendor bank accounts', module_name: 'Cuentas por pagar',
      description: 'View masked bank account information.' },
    { code: 'accounts_payable.banks.manage', name: 'Manage vendor bank accounts', module_name: 'Cuentas por pagar',
      description: 'Add, update and archive vendor bank accounts.' },
    { code: 'accounts_payable.banks.create', name: 'Crear cuentas bancarias de proveedores', module_name: 'Cuentas por pagar',
      description: 'Registrar cuentas bancarias nuevas.' },
    { code: 'accounts_payable.banks.update', name: 'Editar cuentas bancarias de proveedores', module_name: 'Cuentas por pagar',
      description: 'Actualizar datos y estados operativos de cuentas bancarias.' },
    { code: 'accounts_payable.banks.destroy', name: 'Archivar cuentas bancarias de proveedores', module_name: 'Cuentas por pagar',
      description: 'Archivar cuentas bancarias sin eliminarlas físicamente.' },
    { code: 'accounts_payable.banks.restore', name: 'Restaurar cuentas bancarias de proveedores', module_name: 'Cuentas por pagar',
      description: 'Recuperar cuentas bancarias archivadas.' },
    { code: 'accounts_payable.banks.review', name: 'Verificar cuentas bancarias de proveedores', module_name: 'Cuentas por pagar',
      description: 'Aprobar, rechazar o revertir verificaciones bancarias.' },
    { code: 'accounts_payable.banks.reveal', name: 'Reveal bank account numbers', module_name: 'Cuentas por pagar',
      description: 'Access full encrypted banking details with audit logging.' }
  ].freeze
end

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
  SystemRole::ADMINISTRATIVE_CODES.each do |role_code|
    role = SystemRole.available.find_by!(code: role_code)
    AdministratorPermissionProvisioner.call(role:)
  end
end

def seed_admin_user
  language = Language.find_by!(code: 'es')
  administrator_role = SystemRole.find_by!(code: 'administrator')
  user = User.find_or_initialize_by(email: 'administrador@delta.com')
  action = user.new_record? ? 'CREAR' : 'ACTUALIZAR'
  $stdout.puts "[SEEDS][USUARIO][#{action}] Administrador: #{user.email}"
  if user.new_record?
    assign_admin_user_attributes(user, language)
    user.save!
  end
  report_admin_user(user, language)
  assign_admin_role(user, administrator_role)
  report_admin_roles(user)
end

def report_admin_user(user, language)
  $stdout.puts "[SEEDS][USUARIO][OK] id=#{user.id} usuario=#{user.username} " \
               "tipo=#{user.user_type} estado=#{user.status} idioma=#{language.code}"
end

def report_admin_roles(user)
  $stdout.puts "[SEEDS][USUARIO][OK] Administrador configurado; roles=#{user.system_roles.pluck(:code).join(', ')}"
end

def assign_admin_user_attributes(user, language)
  user.assign_attributes(
    username: 'administrador',
    **(user.new_record? ? { password: 'administrador', password_confirmation: 'administrador' } : {}),
    user_type: :employee,
    status: :active,
    theme: Theme::DEFAULT,
    language:
  )
end

def assign_admin_role(user, administrator_role)
  assignment = UserRole.find_or_initialize_by(user:, system_role: administrator_role, branch: nil)
  action = assignment.new_record? ? 'CREAR' : 'VERIFICAR'
  assignment.deleted_at = nil
  assignment.save!
  $stdout.puts "[SEEDS][ROL][#{action}] usuario_id=#{user.id} rol=#{administrator_role.code} " \
               "asignacion_id=#{assignment.id}"
end

unless defined?(USER_SEED_ROLES)
  USER_SEED_ROLES = %w[
    manager supervisor cashier salesman inventory purchases finance auditor support
  ].freeze
end

def seed_users(count = 15)
  roles = SystemRole.where(code: USER_SEED_ROLES).order(:id).to_a
  language = Language.find_by!(code: 'es')
  $stdout.puts "[SEEDS][USUARIOS][INICIO] Procesando #{count} usuarios de ejemplo; roles disponibles=#{roles.length}"
  count.times { |index| seed_example_user(index, count, roles, language) }
  $stdout.puts "[SEEDS][USUARIOS][OK] Total usuarios de ejemplo procesados=#{count}"
end

def seed_example_user(index, count, roles, language)
  user = User.find_or_initialize_by(email: "user#{index + 1}@delta.com")
  action = user.new_record? ? 'CREAR' : 'ACTUALIZAR'
  if user.new_record?
    assign_user_attributes(user, language, index)
    user.save!
  end
  role = roles.fetch(index % roles.length)
  assignment = UserRole.find_or_create_by!(user:, system_role: role, branch: nil)
  $stdout.puts "[SEEDS][USUARIO][#{action}] #{index + 1}/#{count} id=#{user.id} " \
               "usuario=#{user.username} email=#{user.email} estado=#{user.status} " \
               "rol=#{role.code} asignacion_id=#{assignment.id}"
end

def assign_user_attributes(user, language, index)
  user.assign_attributes(
    username: "user#{index + 1}",
    **(user.new_record? ? { password: 'password123', password_confirmation: 'password123' } : {}),
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

require_relative 'seeds/sat_catalogs'
require_relative 'seeds/sat_catalog_csv'
SeedConsole.track('CSV completos del SAT') { SatCatalogCsv.seed! }
SatCatalogSeeds.seed!

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
SeedConsole.report('Regímenes fiscales SAT', SatFiscalRegime)
SeedConsole.report('Contactos', Contact)
SeedConsole.report('Membresías', OrganizationMembership)

# Deterministic examples avoid Faker collisions and invalid phone/address data.
SeedConsole.track('Clientes', Client) do
  20.times do |index|
    number = index + 1
    code = format('CLI%04d', number)
    next if Client.unscoped.exists?(code:)

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
    next if Category.unscoped.exists?(code:)

    Category.create!(
      code:,
      name: "Categoría #{number}",
      description: "Categoría de ejemplo #{number} para Delta POS.",
      status: (number % 5).zero? ? :inactive : :active
    )
  end
end

SeedConsole.track('Productos', Product) do
  organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
  categories = Category.not_deleted.order(:id).to_a
  raise 'No hay categorías disponibles para crear productos' if categories.empty?

  15.times do |index|
    number = index + 1
    code = format('PROD%04d', number)
    next if Product.unscoped.exists?(organization:, code:)

    organization.products.create!(
      code:,
      name: "Producto de ejemplo #{number}",
      description: "Producto de demostración #{number} para Delta POS.",
      price: number * 100,
      cost: number * 60,
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
    next if Branch.unscoped.exists?(organization:, name:)

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
        country: Country.find_by!(iso_alpha2: 'MX'),
        postal_code: '06000'
      }
    )
  end
end

require_relative 'seeds/supplier_dossier_examples'
SeedConsole.track('Expedientes de proveedores') do
  SupplierDossierExamples.seed!
end

require_relative 'seeds/supplier_commercial_examples'
SeedConsole.track('Productos por proveedor', SupplierProduct) do
  SupplierCommercialExamples.seed_products!
end
SeedConsole.track('Cuentas bancarias de proveedores', SupplierBankAccount) do
  SupplierCommercialExamples.seed_bank_accounts!
end
SeedConsole.report('Proveedores preferidos', Product.where.not(preferred_supplier_id: nil))
SeedConsole.report('Direcciones de proveedores', Address.where(addressable_type: 'Supplier'))
SeedConsole.report('Calendarios de proveedores', SupplierSchedule)

SeedConsole.track('Inventarios', Inventory) do
  organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
  branch = organization.branches.not_deleted.order(:id).first
  organization.products.not_deleted.find_each do |product|
    Inventory.find_or_create_by!(organization:, branch:, product:) do |record|
      record.stock = 0
      record.min_stock = 5
      record.max_stock = 300
    end
  end
end

SeedConsole.report('Direcciones', Address)
SeedConsole.finish_run!
