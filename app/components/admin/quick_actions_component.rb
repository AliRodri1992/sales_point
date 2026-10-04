# frozen_string_literal: true

module Admin
  class QuickActionsComponent < ViewComponent::Base
    def initialize(onboarding_progress: nil, sales_requirements: nil)
      @onboarding_progress = onboarding_progress
      @sales_requirements = sales_requirements || {}
    end

    def sales_ready?
      return true unless @onboarding_progress

      @sales_requirements.values.all? { |requirement| requirement[:complete] }
    end

    def sales_missing_sections
      return [] unless @onboarding_progress

      @sales_requirements.filter_map { |section, requirement| section unless requirement[:complete] }
    end

    Action = Data.define(
      :label,
      :description,
      :icon,
      :icon_background,
      :icon_color
    )

    ACTIONS = [
      Action.new(
        label: 'admin.dashboard.widgets.quick_actions.new_sale',
        description: 'admin.dashboard.widgets.quick_actions.open_pos',
        icon: 'plus',
        icon_background: 'bg-blue-500/20',
        icon_color: 'text-blue-400'
      ),
      Action.new(
        label: 'admin.dashboard.widgets.quick_actions.product',
        description: 'admin.dashboard.widgets.quick_actions.add_product',
        icon: 'plus',
        icon_background: 'bg-emerald-500/20',
        icon_color: 'text-emerald-400'
      ),
      Action.new(
        label: 'admin.dashboard.widgets.quick_actions.customer',
        description: 'admin.dashboard.widgets.quick_actions.new_customer',
        icon: 'users',
        icon_background: 'bg-cyan-500/20',
        icon_color: 'text-cyan-400'
      ),
      Action.new(
        label: 'admin.dashboard.widgets.quick_actions.cash_cut',
        description: 'admin.dashboard.widgets.quick_actions.check_cash',
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
