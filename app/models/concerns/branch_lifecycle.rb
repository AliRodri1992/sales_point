# frozen_string_literal: true

# Branch operational state machine and compatibility with the legacy status flag.
# New transitions must be performed through Branches::TransitionStatus.
module BranchLifecycle
  extend ActiveSupport::Concern

  included do
    attr_accessor :lifecycle_transition_authorized, :direct_legacy_status_change

    enum :operational_status, { preparing: 'preparing', active: 'active',
                                suspended: 'suspended', closed: 'closed' },
         default: :preparing, validate: true

    has_many :branch_status_transitions
    after_create :record_initial_operational_status

    before_validation :sync_legacy_status
    around_save :serialize_branch_details_update, if: :regular_branch_update?
    validate :protect_operational_status_change, if: :restricted_lifecycle_change?
    validate :protect_legacy_status_change, if: :direct_legacy_status_change
    validate :protect_closed_changes, if: -> { persisted? && closed? && !lifecycle_transition_authorized }
    validate :prepare_only_deletion, if: -> { will_save_change_to_deleted_at? && deleted_at.present? }
  end

  def operationally_active? = active? && deleted_at.nil? && organization&.active?

  def operational_dependencies? = active_branch_operations?

  private

  def regular_branch_update?
    persisted? && !lifecycle_transition_authorized
  end

  def serialize_branch_details_update
    locked = self.class.with_deleted.find(id)
    locked.with_lock do
      if locked.closed? || locked.deleted_at.present?
        errors.add(:base, I18n.t('admin.branch_lifecycle.errors.closed_readonly'))
        raise ActiveRecord::RecordInvalid, self
      end

      yield
    end
  end

  def record_initial_operational_status
    reason = I18n.t('admin.branch_lifecycle.created_reason') if lifecycle_created_by
    branch_status_transitions.create!(to_status: operational_status,
                                      changed_by: lifecycle_created_by, reason:)
  end

  def sync_legacy_status
    self.direct_legacy_status_change = persisted? && will_save_change_to_status? &&
                                       !lifecycle_transition_authorized
    self.status = operational_status == 'active' unless registration_bootstrap
  end

  def protect_legacy_status_change
    errors.add(:status, :invalid)
  end

  def protect_closed_changes
    changes = changes_to_save.keys - %w[updated_at]
    errors.add(:base, I18n.t('admin.branch_lifecycle.errors.closed_readonly')) if changes.any?
  end

  def restricted_lifecycle_change?
    persisted? && will_save_change_to_operational_status? && !lifecycle_transition_authorized
  end

  def protect_operational_status_change
    errors.add(:operational_status, :invalid)
  end

  def prepare_only_deletion
    errors.add(:base, I18n.t('admin.branch_lifecycle.errors.delete_requires_preparing')) unless preparing?
  end
end
