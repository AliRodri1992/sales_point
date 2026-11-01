# frozen_string_literal: true

module MembershipCatalogExamples
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
      limits: {
        'max_users' => 3, 'max_branches' => 1, 'max_products' => 500,
        'max_clients' => 500, 'max_suppliers' => 25, 'max_warehouses' => 1,
        'max_pos_terminals' => 1
      }
    },
    'professional' => {
      enabled: %w[pos customers suppliers products inventory cash_registers reports multi_branch expenses exports],
      limits: {
        'max_users' => 10, 'max_branches' => 3, 'max_products' => 5000,
        'max_clients' => 5000, 'max_suppliers' => 500, 'max_warehouses' => 3,
        'max_pos_terminals' => 5
      }
    },
    'business' => {
      enabled: %w[
        pos customers suppliers products inventory advanced_inventory cash_registers
        reports advanced_reports multi_branch expenses exports
      ],
      limits: {
        'max_users' => 30, 'max_branches' => 10, 'max_products' => nil,
        'max_clients' => nil, 'max_suppliers' => nil, 'max_warehouses' => 10,
        'max_pos_terminals' => 20
      }
    },
    'enterprise' => {
      enabled: %w[
        pos customers suppliers products inventory advanced_inventory cash_registers
        reports advanced_reports multi_branch expenses api exports
      ],
      limits: {
        'max_users' => nil, 'max_branches' => nil, 'max_products' => nil,
        'max_clients' => nil, 'max_suppliers' => nil, 'max_warehouses' => nil,
        'max_pos_terminals' => nil
      }
    }
  }.freeze

  def self.seed!
    seed_features!
    seed_plans!
  end

  def self.seed_features!
    MEMBERSHIP_FEATURES.each do |attributes|
      feature = MembershipFeature.find_or_initialize_by(key: attributes[:key])
      feature.assign_attributes(attributes.merge(active: true))
      feature.save!
    end
  end

  def self.seed_plans!
    MEMBERSHIP_PLANS.each do |attributes|
      plan = MembershipPlan.find_or_initialize_by(slug: attributes[:slug])
      plan.assign_attributes(attributes)
      plan.save!

      configuration = MEMBERSHIP_PLAN_CONFIGURATION.fetch(plan.slug)
      MembershipFeature.where(deleted_at: nil).find_each do |feature|
        seed_plan_feature!(plan, feature, configuration)
      end
    end
  end

  def self.seed_plan_feature!(plan, feature, configuration)
    assignment = MembershipPlanFeature.find_or_initialize_by(membership_plan: plan, membership_feature: feature)
    limit = configuration[:limits][feature.key]
    unlimited = configuration[:limits].key?(feature.key) && limit.nil?

    assignment.assign_attributes(
      enabled: configuration[:enabled].include?(feature.key),
      limit: limit,
      value: unlimited ? 'unlimited' : nil,
      position: feature.position,
      deleted_at: nil
    )
    assignment.value = 'true' if feature.value_type == 'boolean' && assignment.enabled?
    assignment.save!
  end
end
