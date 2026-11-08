# frozen_string_literal: true

module Users
  # Persists admin-edited accounts without replacing branch-scoped role assignments.
  # User creation, organization membership and global role updates are atomic.
  class AdminAccountWriter
    include AdminAccountTenantGuard

    def initialize(user:, organization:, attributes:, actor: nil)
      @user = user
      @organization = organization
      @attributes = attributes
      @actor = actor
    end

    def email_changed?
      @email_changed == true
    end

    def save
      @user.assign_attributes(user_attributes)
      prepare_new_account if @user.new_record?
      role_ids = requested_role_ids
      branch_roles = branch_role_editor
      return false unless valid_access_selection?(role_ids, branch_roles)
      return false unless @user.valid? && tenant_safe_update?(role_ids)

      persist!(role_ids, branch_roles)
      Users::SessionRevoker.call(@user) if @access_changed
      true
    rescue ActiveRecord::RecordInvalid, Users::OrganizationCapacity::CapacityExceeded => e
      @user.errors.add(:base, e.message) if @user.errors.empty?
      false
    end

    private

    def prepare_new_account
      @user.status = :pending
      @user.password = SecureRandom.urlsafe_base64(36)
      @user.password_confirmation = @user.password
      return if @user.language_id.present?

      @user.language = Language.selectable.find_by(code: I18n.locale.to_s) ||
                       Language.selectable.find_by(code: 'es')
    end

    def user_attributes
      @attributes.except(:system_role_ids, :branch_role_assignments, :status, :password, :password_confirmation)
    end

    def requested_role_ids
      values = @attributes[:system_role_ids]
      return nil if values.nil?

      provided = Array(values).compact_blank
      return :invalid unless provided.all? { |value| value.to_s.match?(/\A\d+\z/) }

      ids = provided.map(&:to_i).uniq
      allowed = SystemRole.selectable_for(@user).system.where(id: ids).pluck(:id)
      return :invalid unless ids.sort == allowed.sort
      return :invalid unless permitted_administrative_roles?(ids)

      ids
    end

    def permitted_administrative_roles?(ids)
      return true if @actor&.role?('super_admin')

      protected = SystemRole.system.where(code: SystemRole::ADMINISTRATIVE_CODES).pluck(:id)
      current = @user.user_roles.where(deleted_at: nil, branch_id: nil, system_role_id: protected)
                     .pluck(:system_role_id)
      (ids & protected).sort == current.sort
    end

    def prepare_admin_access_validation(role_ids, branch_roles)
      @user.admin_role_selection_required = @user.new_record? || !role_ids.nil? ||
                                            !@attributes[:branch_role_assignments].nil? ||
                                            @user.will_save_change_to_user_type?
      @user.admin_selected_system_roles = role_ids ||
                                          @user.user_roles.active.where(branch_id: nil).pluck(:system_role_id)
      @user.admin_selected_branch_roles = branch_roles.selected_pairs
    end

    def branch_role_editor
      Users::BranchRoleAssignments.new(
        user: @user, organization: @organization, tokens: @attributes[:branch_role_assignments]
      )
    end

    def valid_access_selection?(role_ids, branch_roles)
      return false unless delegated_employee_allowed?

      return invalid_role_error?(:system_role_ids) if role_ids == :invalid
      return invalid_role_error?(:branch_role_assignments) unless branch_roles.valid?

      prepare_admin_access_validation(role_ids, branch_roles)
      true
    end

    def invalid_role_error?(attribute)
      @user.valid?
      @user.errors.add(attribute, :invalid)
      false
    end

    def persist!(role_ids, branch_roles)
      @organization.with_lock do
        Users::OrganizationCapacity.new(organization: @organization).ensure_available! if @user.new_record?
        persist_account!(role_ids, branch_roles)
      end
    end

    def persist_account!(role_ids, branch_roles)
      User.transaction do
        created = @user.new_record?
        @user.save!
        raise ActiveRecord::RecordInvalid, @user unless last_admin_role_safe?(role_ids)

        previous_access = active_assignment_pairs
        handle_account_membership(created)
        sync_system_roles!(role_ids) unless role_ids.nil?
        branch_roles.apply!
        revoke_changed_access!(created, previous_access)
      end
    end

    def handle_account_membership(created)
      @email_changed = !created && @user.saved_change_to_email? && @user.pending?
      UserInvitation.revoke_for!(@user) if @email_changed
      return unless created

      @user.organization_memberships.create!(
        organization: @organization, status: :active, account_status: :pending
      )
    end

    def revoke_changed_access!(created, previous_access)
      @access_changed = !created && previous_access != active_assignment_pairs
      @user.update!(session_revoked_at: Time.current) if @access_changed
    end

    def active_assignment_pairs
      @user.user_roles.active.pluck(:system_role_id, :branch_id).sort_by { |id, branch| [id, branch || 0] }
    end

    def sync_system_roles!(role_ids)
      assignments = @user.user_roles.joins(:system_role).where(branch_id: nil, deleted_at: nil)
                         .where(system_roles: { role_type: 'system' })
      current_ids = assignments.pluck(:system_role_id)
      assignments.where.not(system_role_id: role_ids).find_each do |assignment|
        assignment.update!(deleted_at: Time.current)
      end
      (role_ids - current_ids).each { |id| @user.user_roles.create!(system_role_id: id) }
    end
  end
end
