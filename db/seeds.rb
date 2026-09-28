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
    description: 'Permite administrar roles y sus permisos.' },
  { code: 'organizations.access', name: 'Acceso a organizaciones', module_name: 'Organizaciones',
    description: 'Permite administrar organizaciones.' },
  { code: 'membership_plans.access', name: 'Acceso a planes de membresía', module_name: 'Membresías',
    description: 'Permite administrar planes de membresía.' },
  { code: 'subscriptions.access', name: 'Acceso a suscripciones', module_name: 'Membresías',
    description: 'Permite administrar suscripciones.' }
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
  role_codes = %w[super_admin administrator]
  permissions = Permission.available

  SystemRole.where(code: role_codes).find_each do |role|
    assign_permissions_to_role(role, permissions)
  end
end

def assign_permissions_to_role(role, permissions)
  permissions.find_each do |permission|
    SystemRolePermission.find_or_create_by!(system_role: role, permission: permission)
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
seed_permissions
assign_default_role_permissions
seed_admin_user

require 'faker'

# Create client examples
20.times do |index|
  code = "CLI#{format('%04d', index + 1)}"

  name = Faker::Company.name
                       .gsub(/[^A-Za-z0-9ÁÉÍÓÚáéíóúÑñ&.-]/, '')
                       .strip

  rfc_prefix = index.even? ? 3 : 4

  rfc = "#{Faker::Alphanumeric.alpha(number: rfc_prefix).upcase}" \
        "#{Faker::Number.number(digits: 6)}" \
        "#{Faker::Alphanumeric.alphanumeric(number: 3).upcase}"

  postal_code = format('%05d', Faker::Number.between(from: 1, to: 99_999))

  Client.create!(
    code: code,
    email: Faker::Internet.unique.email,
    name: name,
    notes: Faker::Lorem.sentence(word_count: 8),
    phone: Faker::PhoneNumber.cell_phone,
    postal_code: postal_code,
    credit_limit: Faker::Number.between(from: 0, to: 100_000),
    rfc: rfc,
    status: %w[active inactive].sample
  )
rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
  Rails.logger.warn "Skipping client seed due to error: #{e.message}"
end

# Create category examples
15.times do |index|
  name = Faker::Commerce.department(max: 1).gsub(/[^a-zA-Z0-9ÁÉÍÓÚáéíóúÑñ]/, '')
  name = "Categoria#{index + 1}" if name.blank?

  Category.create!(
    code: "cat#{format('%04d', index + 1)}",
    name: name[0, 50],
    description: Faker::Lorem.sentence(word_count: 8),
    status: %w[active active active inactive].sample
  )
rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
  Rails.logger.warn "Skipping category seed due to error: #{e.message}"
end

categories = Category.not_deleted.to_a

# Create product examples
15.times do |index|
  code = "PROD#{format('%04d', index + 1)}"

  name = Faker::Commerce.product_name
  price = Faker::Commerce.price(range: 50.0..5000.0)
  stock = Faker::Number.between(from: 10, to: 500)

  Product.create!(
    code: code,
    name: name,
    description: Faker::Lorem.sentence(word_count: 12),
    price: price,
    cost: (price * 0.6).round(2),
    stock: stock,
    min_stock: 5,
    max_stock: stock + 100,
    sku: "SKU-#{Faker::Alphanumeric.alphanumeric(number: 8).upcase}",
    barcode: "75#{Faker::Number.number(digits: 10)}",
    category: categories.sample,
    status: %w[active active active inactive].sample
  )
rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
  Rails.logger.warn "Skipping product seed due to error: #{e.message}"
end

# Create branch examples
15.times do |index|
  street = Faker::Address.street_name
  neighborhood = Faker::Address.city
  city = Faker::Address.city
  state = Faker::Address.state
  exterior_number = Faker::Address.building_number.to_s.strip
  exterior_number = Faker::Number.between(from: 1, to: 999).to_s if exterior_number.blank?
  postal_code = format('%05d', Faker::Address.zip_code.to_s.gsub(/\D/, '')[0, 5].to_i)
  phone = Faker::PhoneNumber.cell_phone.gsub(/[^0-9+\-()\s]/, '')[0, 20]

  Branch.create!(
    name: "Sucursal #{format('%02d', index + 1)} - #{neighborhood}"[0, 100],
    phone: phone,
    status: [true, true, true, false].sample,
    address_attributes: {
      street: street[0, 150],
      exterior_number: exterior_number,
      neighborhood: neighborhood[0, 100],
      city: city[0, 100],
      state: state[0, 100],
      country: 'España',
      postal_code: postal_code
    }
  )
rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
  Rails.logger.warn "Skipping branch seed due to error: #{e.message}"
end

MEMBERSHIP_FEATURES = [
  { key: 'pos', name: 'Punto de venta', value_type: :boolean, position: 1 },
  { key: 'customers', name: 'Clientes', value_type: :boolean, position: 2 },
  { key: 'suppliers', name: 'Proveedores', value_type: :boolean, position: 3 },
  { key: 'products', name: 'Productos', value_type: :boolean, position: 4 },
  { key: 'inventory', name: 'Inventario', value_type: :boolean, position: 5 },
  { key: 'advanced_inventory', name: 'Inventario avanzado', value_type: :boolean, position: 6 },
  { key: 'cash_registers', name: 'Cajas', value_type: :boolean, position: 7 },
  { key: 'reports', name: 'Reportes', value_type: :boolean, position: 8 },
  { key: 'advanced_reports', name: 'Reportes avanzados', value_type: :boolean, position: 9 },
  { key: 'multi_branch', name: 'Multi-sucursal', value_type: :boolean, position: 10 },
  { key: 'expenses', name: 'Gastos', value_type: :boolean, position: 11 },
  { key: 'api', name: 'API', value_type: :boolean, position: 12 },
  { key: 'exports', name: 'Exportaciones', value_type: :boolean, position: 13 },
  { key: 'max_users', name: 'Máximo de usuarios', value_type: :integer, position: 20 },
  { key: 'max_branches', name: 'Máximo de sucursales', value_type: :integer, position: 21 },
  { key: 'max_products', name: 'Máximo de productos', value_type: :integer, position: 22 },
  { key: 'max_clients', name: 'Máximo de clientes', value_type: :integer, position: 23 },
  { key: 'max_suppliers', name: 'Máximo de proveedores', value_type: :integer, position: 24 },
  { key: 'max_warehouses', name: 'Máximo de almacenes', value_type: :integer, position: 25 },
  { key: 'max_pos_terminals', name: 'Máximo de terminales POS', value_type: :integer, position: 26 }
].freeze

MEMBERSHIP_PLANS = [
  {
    name: 'Starter',
    slug: 'starter',
    description: 'Para negocios que comienzan a organizar sus ventas.',
    price: 299.00,
    currency: 'MXN',
    billing_interval: :monthly,
    trial_days: 14,
    position: 1,
    active: true
  },
  {
    name: 'Professional',
    slug: 'professional',
    description: 'Para negocios que necesitan inventario, reportes y crecimiento multi-sucursal.',
    price: 599.00,
    currency: 'MXN',
    billing_interval: :monthly,
    trial_days: 14,
    position: 2,
    active: true
  },
  {
    name: 'Business',
    slug: 'business',
    description: 'Para operaciones con múltiples sucursales y mayores límites.',
    price: 999.00,
    currency: 'MXN',
    billing_interval: :monthly,
    trial_days: 14,
    position: 3,
    active: true
  },
  {
    name: 'Enterprise',
    slug: 'enterprise',
    description: 'Para organizaciones con necesidades empresariales y API.',
    price: 0.00,
    currency: 'MXN',
    billing_interval: :monthly,
    trial_days: 0,
    position: 4,
    active: true
  }
].freeze

MEMBERSHIP_PLAN_CONFIGURATION = {
  'starter' => {
    enabled: %w[pos customers products cash_registers reports],
    limits: { 'max_users' => 3, 'max_branches' => 1, 'max_products' => 500, 'max_clients' => 500, 'max_suppliers' => 25, 'max_warehouses' => 1, 'max_pos_terminals' => 1 }
  },
  'professional' => {
    enabled: %w[pos customers suppliers products inventory cash_registers reports multi_branch expenses exports],
    limits: { 'max_users' => 10, 'max_branches' => 3, 'max_products' => 5000, 'max_clients' => 5000, 'max_suppliers' => 500, 'max_warehouses' => 3, 'max_pos_terminals' => 5 }
  },
  'business' => {
    enabled: %w[pos customers suppliers products inventory advanced_inventory cash_registers reports advanced_reports multi_branch expenses exports],
    limits: { 'max_users' => 30, 'max_branches' => 10, 'max_products' => nil, 'max_clients' => nil, 'max_suppliers' => nil, 'max_warehouses' => 10, 'max_pos_terminals' => 20 }
  },
  'enterprise' => {
    enabled: %w[pos customers suppliers products inventory advanced_inventory cash_registers reports advanced_reports multi_branch expenses api exports],
    limits: { 'max_users' => nil, 'max_branches' => nil, 'max_products' => nil, 'max_clients' => nil, 'max_suppliers' => nil, 'max_warehouses' => nil, 'max_pos_terminals' => nil }
  }
}.freeze

def seed_membership_catalog
  MEMBERSHIP_FEATURES.each do |attributes|
    feature = MembershipFeature.find_or_initialize_by(key: attributes[:key])
    feature.assign_attributes(attributes.merge(active: true))
    feature.save!
  end

  MEMBERSHIP_PLANS.each do |attributes|
    plan = MembershipPlan.find_or_initialize_by(slug: attributes[:slug])
    plan.assign_attributes(attributes)
    plan.save!

    configuration = MEMBERSHIP_PLAN_CONFIGURATION.fetch(plan.slug)

    MembershipFeature.where(deleted_at: nil).find_each do |feature|
      plan_feature = MembershipPlanFeature.find_or_initialize_by(
        membership_plan: plan,
        membership_feature: feature
      )
      plan_feature.assign_attributes(
        enabled: configuration[:enabled].include?(feature.key),
        limit: configuration[:limits][feature.key],
        value: configuration[:limits].key?(feature.key) && configuration[:limits][feature.key].nil? ? 'unlimited' : nil,
        position: feature.position,
        deleted_at: nil
      )
      plan_feature.value = 'true' if feature.value_type == 'boolean' && plan_feature.enabled?
      plan_feature.save!
    end
  end
end

def seed_demo_organization
  organization = Organization.find_or_initialize_by(code: 'DELTA-DEMO')
  organization.assign_attributes(
    name: 'Delta POS Demo',
    legal_name: 'Delta POS Demo',
    email: 'demo@delta.com',
    phone: '5555555555',
    status: 'active',
    deleted_at: nil
  )
  organization.save!

  plan = MembershipPlan.find_by!(slug: 'professional')
  subscription = organization.subscriptions.current.first_or_initialize
  subscription.assign_attributes(
    membership_plan: plan,
    status: 'active',
    starts_at: Time.current,
    ends_at: nil,
    trial_ends_at: nil,
    canceled_at: nil
  )
  subscription.save!

  subscription.subscription_events.find_or_create_by!(
    event_type: 'subscription_created',
    membership_plan: plan,
    to_status: 'active'
  ) do |event|
    event.description = 'Initial Delta POS demo subscription.'
  end
end

seed_membership_catalog
seed_demo_organization
