# frozen_string_literal: true

# Newly originated purchases must target an active branch.
# Existing operations may be completed during suspension, but cannot be moved
# to an inactive branch.
module RequiresOperationalBranch
  extend ActiveSupport::Concern

  included do
    validate :branch_must_be_operational, if: :requires_operational_branch_check?
    around_save :serialize_operational_branch_change, if: :requires_operational_branch_check?
  end

  private

  def requires_operational_branch_check?
    new_record? || will_save_change_to_branch_id?
  end

  def serialize_operational_branch_change
    branch.with_lock do
      branch_must_be_operational
      raise ActiveRecord::RecordInvalid, self if errors[:branch].any?

      yield
    end
  end

  def branch_must_be_operational
    errors.add(:branch, :invalid) unless branch&.operationally_active?
  end
end
