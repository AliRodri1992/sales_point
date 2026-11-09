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
      {
        organization: organization&.active? == true,
        name: valid_branch_name?,
        code: valid_branch_code?,
        address: branch.address&.valid? == true,
        currency: active_base_currency?,
        team: manager_assigned?
      }
    end

    def blockers_for(status)
      case status.to_s
      when 'active' then activation.reject { |_key, ready| ready }.keys
      when 'suspended' then suspension_blockers
      when 'closed' then closure_blockers
      else []
      end
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
      blockers.concat(purchase_blockers)
      blockers << :assigned_team if branch.user_roles.active.exists?
      blockers
    end

    private

    attr_reader :branch, :actor

    def organization = branch.organization

    def valid_branch_name?
      branch.name.to_s.length.between?(3, 150)
    end

    def valid_branch_code?
      branch.code.present? && branch.code.match?(/\A[A-Z0-9_-]{1,30}\z/)
    end

    def active_base_currency?
      relation = organization&.organization_settings
      settings = relation&.active_records&.first
      settings&.base_currency&.active? == true
    end

    def purchase_blockers
      blockers = []
      blockers << :pending_requests if branch.purchase_requests.exists?(status: OPEN_REQUESTS)
      blockers << :pending_orders if branch.purchase_orders.exists?(status: OPEN_ORDERS)
      returns = PurchaseReturn.joins(:goods_receipt)
      blockers << :pending_returns if returns.exists?(goods_receipts: { branch_id: branch.id }, status: 'draft')
      blockers
    end

    def outstanding_inventory?
      return true if branch.inventories.where('stock > 0').exists?

      lots = InventoryLot.joins(:inventory).where(inventories: { branch_id: branch.id })
      return true if lots.where('inventory_lots.quantity > 0').exists?

      InventorySerial.joins(inventory_lot: :inventory)
                     .exists?(inventories: { branch_id: branch.id }, status: %w[available quarantined])
    end

    def manager_assigned?
      return false unless organization

      membership = actor&.organization_memberships&.accessible
      administrator = actor&.admin? &&
                      membership&.exists?(organization_id: organization.id)
      administrator || Branch.team_assignments(organization).exists?(branch_id: branch.id)
    end

    def last_active_branch?
      return false unless organization&.active? && organization.onboarding_completed? && branch.active?

      organization.branches.not_deleted.where(operational_status: 'active').where.not(id: branch.id).none?
    end
  end
end
