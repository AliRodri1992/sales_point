# frozen_string_literal: true

class GranularPermissionCatalog
  MODULES = {
    'languages' => 'Idiomas', 'products' => 'Productos', 'customers' => 'Clientes',
    'users' => 'Usuarios', 'categories' => 'Categorías'
  }.freeze
  ACTIONS = %w[access index show create update destroy].freeze

  def self.sync!
    MODULES.each do |prefix, label|
      ACTIONS.each do |action|
        Permission.find_or_create_by!(code: "#{prefix}.#{action}") do |permission|
          permission.name = "#{action.humanize} #{label}"
          permission.module_name = label
          permission.description = "#{action.humanize}: #{label}"
          permission.status = :active
        end
      end
    end
  end
end
