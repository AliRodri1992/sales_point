# frozen_string_literal: true

class GranularPermissionCatalog
  MODULES = {
    'languages' => 'Idiomas', 'products' => 'Productos', 'customers' => 'Clientes',
    'users' => 'Usuarios', 'categories' => 'Categorías',
    'units_of_measure' => 'Unidades de medida'
  }.freeze
  ACTIONS = %w[access index show create update destroy].freeze
  COMMERCIAL_ACTIONS = %w[access index show create update archive activate pause resume duplicate history].freeze
  PRICE_LIST_ACTIONS = (COMMERCIAL_ACTIONS + %w[view_margin authorize_below_cost]).freeze

  def self.sync!
    MODULES.each { |prefix, label| sync_module(prefix, label, ACTIONS) }
    sync_module('price_lists', 'Listas de precios', PRICE_LIST_ACTIONS)
    sync_module('promotions', 'Promociones', COMMERCIAL_ACTIONS)
  end

  def self.sync_module(prefix, label, actions)
    actions.each do |action|
      Permission.find_or_create_by!(code: "#{prefix}.#{action}") do |permission|
        permission.name = "#{action.humanize} #{label}"
        permission.module_name = label
        permission.description = "#{action.humanize}: #{label}"
        permission.status = :active
      end
    end
  end
  private_class_method :sync_module
end
