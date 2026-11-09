# frozen_string_literal: true

module Admin
  # Data visible on the branch detail screen. Neighbor modules are consulted
  # only for lifecycle contracts; each transition is evaluated once per request.
  module BranchDetail
    private

    def load_branch_detail
      @branch_team_count = Branch.team_assignments(current_organization)
                                 .where(branch_id: @branch.id).distinct.count(:user_id)
      can_manage = policy(@branch).manage?
      load_branch_lifecycle_display(can_manage)
      return unless can_manage

      @branch_operation_counts = { products: @branch.inventories.distinct.count(:product_id),
                                   terminals: @branch.terminals.not_deleted.count }
      load_branch_change_events
    end

    def load_branch_lifecycle_display(can_manage)
      requirements = Branches::LifecycleRequirements.new(branch: @branch, actor: current_user)
      @branch_activation_requirements = requirements.activation if @branch.preparing? || @branch.suspended?
      @branch_transition_blockers = branch_transition_blockers_for_view(requirements) if can_manage
    end

    def branch_transition_blockers_for_view(requirements)
      allowed = Branches::TransitionStatus::ALLOWED.fetch(@branch.operational_status, [])
      allowed.index_with do |target|
        if target == 'active' && @branch_activation_requirements
          @branch_activation_requirements.reject { |_key, ready| ready }.keys
        else
          requirements.blockers_for(target)
        end
      end
    end
  end
end
