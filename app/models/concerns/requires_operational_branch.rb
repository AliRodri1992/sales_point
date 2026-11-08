# frozen_string_literal: true

# Newly originated purchases must target an active branch.
# Existing operations may be completed during suspension, but cannot be moved
# to an inactive branch.
module RequiresOperationalBranch
  extend ActiveSupport::Concern

  included do
    validate :branch_must_be_operational, if: -> { new_record? || will_save_change_to_branch_id? }
  end

  private

  def branch_must_be_operational
    errors.add(:branch, :invalid) unless branch&.operationally_active?
  end
end
