# frozen_string_literal: true

module Users
  # Applies branch role selections only within the current organization.
  class BranchRoleAssignments
    def initialize(user:, organization:, tokens:)
      @user = user
      @organization = organization
      @tokens = tokens
    end

    def valid?
      return true if @tokens.nil?

      parsed = parse_tokens
      parsed && valid_branch_ids?(parsed) && valid_role_ids?(parsed)
    end

    def apply!
      return if @tokens.nil?

      desired = parse_tokens
      existing = local_assignments.to_a
      revoke_missing!(existing, desired)
      create_missing!(existing, desired)
    end

    private

    def valid_branch_ids?(parsed)
      ids = parsed.map(&:first).uniq
      allowed = @organization.branches.not_deleted.where(status: true, id: ids).pluck(:id)
      ids.sort == allowed.sort
    end

    def valid_role_ids?(parsed)
      ids = parsed.map(&:last).uniq
      allowed = SystemRole.branch.active.not_deleted.where(id: ids).pluck(:id)
      ids.sort == allowed.sort
    end

    def local_assignments
      @user.user_roles.active.where(branch_id: @organization.branches.select(:id))
           .where(system_roles: { role_type: 'branch' })
    end

    def revoke_missing!(existing, desired)
      existing.each do |assignment|
        next if desired.include?([assignment.branch_id, assignment.system_role_id])

        assignment.update!(deleted_at: Time.current)
      end
    end

    def create_missing!(existing, desired)
      active_pairs = existing.map { |assignment| [assignment.branch_id, assignment.system_role_id] }
      (desired - active_pairs).each do |branch_id, role_id|
        @user.user_roles.create!(branch_id:, system_role_id: role_id)
      end
    end

    def parse_tokens
      values = Array(@tokens).compact_blank.uniq
      return [] if values.empty?
      return unless values.all? { |value| value.to_s.match?(/\A\d+:\d+\z/) }

      values.map { |value| value.split(':').map(&:to_i) }
    end
  end
end
