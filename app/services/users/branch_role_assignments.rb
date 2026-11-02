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
      return false unless parsed

      branch_ids = parsed.map(&:first).uniq
      role_ids = parsed.map(&:last).uniq
      valid_branches = @organization.branches.not_deleted.where(status: true, id: branch_ids).pluck(:id)
      valid_roles = SystemRole.branch.active.not_deleted.where(id: role_ids).pluck(:id)
      branch_ids.sort == valid_branches.sort && role_ids.sort == valid_roles.sort
    end

    def apply!
      return if @tokens.nil?

      desired = parse_tokens
      assignments = @user.user_roles.active.where(branch_id: @organization.branches.select(:id))
                         .where(system_roles: { role_type: 'branch' })
      existing = assignments.map { |assignment| [assignment.branch_id, assignment.system_role_id] }
      assignments.each do |assignment|
        next if desired.include?([assignment.branch_id, assignment.system_role_id])

        assignment.update!(deleted_at: Time.current)
      end
      (desired - existing).each do |branch_id, role_id|
        @user.user_roles.create!(branch_id:, system_role_id: role_id)
      end
    end

    private

    def parse_tokens
      values = Array(@tokens).compact_blank.uniq
      return [] if values.empty?
      return unless values.all? { |value| value.to_s.match?(/\A\d+:\d+\z/) }

      values.map { |value| value.split(':').map(&:to_i) }
    end
  end
end
