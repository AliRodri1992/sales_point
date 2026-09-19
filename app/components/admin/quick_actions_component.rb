# frozen_string_literal: true

module Admin
  class QuickActionsComponent < ViewComponent::Base
    Action = Data.define(
      :label,
      :description,
      :icon,
      :icon_background,
      :icon_color
    )

    ACTIONS = [
      Action.new(
        label: 'Nueva venta',
        description: 'Abrir POS',
        icon: 'plus',
        icon_background: 'bg-blue-500/20',
        icon_color: 'text-blue-400'
      ),
      Action.new(
        label: 'Producto',
        description: 'Agregar producto',
        icon: 'plus',
        icon_background: 'bg-emerald-500/20',
        icon_color: 'text-emerald-400'
      ),
      Action.new(
        label: 'Cliente',
        description: 'Nuevo cliente',
        icon: 'users',
        icon_background: 'bg-cyan-500/20',
        icon_color: 'text-cyan-400'
      ),
      Action.new(
        label: 'Corte de caja',
        description: 'Consultar caja',
        icon: 'plus',
        icon_background: 'bg-violet-500/20',
        icon_color: 'text-violet-400'
      )
    ].freeze

    private

    def actions
      ACTIONS
    end
  end
end
