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
      role_ids = requested_role_ids
      return invalid_role_error if role_ids == :invalid

      User.transaction do
        created = @user.new_record?
        @user.save!
        @user.organization_memberships.create!(organization: @organization, status: :active) if created
        sync_system_roles!(role_ids) unless role_ids.nil?
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      @user.errors.add(:base, e.message) if @user.errors.empty?
      false
    end

    private

    def user_attributes
      permitted = @attributes.except(:system_role_ids)
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
      allowed = SystemRole.system.active.where(id: ids).pluck(:id)
      ids.sort == allowed.sort ? ids : :invalid
    end

    def invalid_role_error
      @user.valid?
      @user.errors.add(:system_role_ids, :invalid)
      false
    end

    def sync_system_roles!(role_ids)
      assignments = @user.user_roles.active.where(branch_id: nil)
                          .where(system_roles: { role_type: 'system' })
      current_ids = assignments.pluck(:system_role_id)
      assignments.where.not(system_role_id: role_ids).each do |assignment|
        assignment.update!(deleted_at: Time.current)
      end
      (role_ids - current_ids).each { |id| @user.user_roles.create!(system_role_id: id) }
    end
  end
end
