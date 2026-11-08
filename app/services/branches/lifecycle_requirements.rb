# frozen_string_literal: true

module Branches
  # Shared, server-side prerequisites for activation, suspension and closure.
  # Terminals are configured registers, not evidence that a cash session is open.
  class LifecycleRequirements
    OPEN_ORDERS = %w[draft pending_approval approved ordered partially_received].freeze
    OPEN_REQUESTS = %w[draft submitted approved].freeze

    def initialize(branch:, actor: nil)
      @branch = branch
      @actor = actor
    end

    def activation
      settings = organization&.organization_settings&.active_records&.first
      {
        organization: organization&.active? == true,
        name: branch.name.to_s.length.between?(3, 150),
        code: branch.code.present? && branch.code.match?(/\A[A-Z0-9_-]{1,30}\z/),
        address: branch.address&.valid? == true,
        currency: settings&.base_currency&.active? == true,
        team: manager_assigned?
      }
    end

    def suspension_blockers
      blockers = []
      blockers << :active_terminals if branch.terminals.active_records.exists?
      blockers << :last_active_branch if last_active_branch?
      blockers
    end

    def closure_blockers
      blockers = suspension_blockers
      blockers << :outstanding_stock if outstanding_inventory?
      blockers << :pending_requests if branch.purchase_requests.where(status: OPEN_REQUESTS).exists?
      blockers << :pending_orders if branch.purchase_orders.where(status: OPEN_ORDERS).exists?
      returns = PurchaseReturn.joins(:goods_receipt)
                              .where(goods_receipts: { branch_id: branch.id }, status: 'draft')
      blockers << :pending_returns if returns.exists?
      blockers << :assigned_team if branch.user_roles.active.exists?
      blockers
    end

    private

    attr_reader :branch, :actor

    def organization = branch.organization

    def outstanding_inventory?
      return true if branch.inventories.where('stock > 0').exists?

      lots = InventoryLot.joins(:inventory).where(inventories: { branch_id: branch.id })
      return true if lots.where('inventory_lots.quantity > 0').exists?

      InventorySerial.joins(inventory_lot: :inventory)
                     .where(inventories: { branch_id: branch.id }, status: %w[available quarantined]).exists?
    end

    def manager_assigned?
      return false unless organization

      membership = actor&.organization_memberships&.accessible
      administrator = actor&.admin? &&
                      membership&.exists?(organization_id: organization.id)
      administrator || Branch.team_assignments(organization).where(branch_id: branch.id).exists?
    end

    def last_active_branch?
      return false unless organization&.active? && organization.onboarding_completed? && branch.active?

      organization.branches.not_deleted.where(operational_status: 'active').where.not(id: branch.id).none?
    end
  end
end
