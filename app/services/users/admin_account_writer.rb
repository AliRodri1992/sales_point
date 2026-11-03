# frozen_string_literal: true

module Users
  # Persists admin-edited accounts without replacing branch-scoped role assignments.
  # User creation, organization membership and global role updates are atomic.
  class AdminAccountWriter
    def initialize(user:, organization:, attributes:)
      @user = user
      @organization = organization
      @attributes = attributes
    end

    def save
      @user.assign_attributes(user_attributes)
      if @user.new_record?
        @user.status = :pending
        @user.password = SecureRandom.urlsafe_base64(36)
        @user.password_confirmation = @user.password
      end
      role_ids = requested_role_ids
      branch_roles = branch_role_editor
      return invalid_role_error?(:system_role_ids) if role_ids == :invalid
      return invalid_role_error?(:branch_role_assignments) unless branch_roles.valid?

      persist!(role_ids, branch_roles)
      true
    rescue ActiveRecord::RecordInvalid => e
      @user.errors.add(:base, e.message) if @user.errors.empty?
      false
    end

    private

    def user_attributes
      permitted = @attributes.except(:system_role_ids, :branch_role_assignments, :status)
      permitted = permitted.except(:password, :password_confirmation) if @user.new_record?
      if permitted[:password].blank?
        permitted.delete(:password)
        permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
      end
      permitted
    end

    def requested_role_ids
      values = @attributes[:system_role_ids]
      return nil if values.nil?

      provided = Array(values).compact_blank
      return :invalid unless provided.all? { |value| value.to_s.match?(/\A\d+\z/) }

      ids = provided.map(&:to_i).uniq
      allowed = SystemRole.system.active.not_deleted.where(id: ids).pluck(:id)
      ids.sort == allowed.sort ? ids : :invalid
    end

    def branch_role_editor
      Users::BranchRoleAssignments.new(
        user: @user, organization: @organization, tokens: @attributes[:branch_role_assignments]
      )
    end

    def invalid_role_error?(attribute)
      @user.valid?
      @user.errors.add(attribute, :invalid)
      false
    end

    def persist!(role_ids, branch_roles)
      User.transaction do
        created = @user.new_record?
        @user.save!
        @user.organization_memberships.create!(organization: @organization, status: :active) if created
        sync_system_roles!(role_ids) unless role_ids.nil?
        branch_roles.apply!
      end
    end

    def sync_system_roles!(role_ids)
      assignments = @user.user_roles.active.where(branch_id: nil).where(system_roles: { role_type: 'system' })
      current_ids = assignments.pluck(:system_role_id)
      assignments.where.not(system_role_id: role_ids).find_each do |assignment|
        assignment.update!(deleted_at: Time.current)
      end
      (role_ids - current_ids).each { |id| @user.user_roles.create!(system_role_id: id) }
    end
  end
end
