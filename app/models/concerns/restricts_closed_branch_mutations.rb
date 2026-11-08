# frozen_string_literal: true

# Ensures branch details remain read-only after a permanent closure.
module RestrictsClosedBranchMutations
  extend ActiveSupport::Concern

  included do
    validate :reject_closed_branch_owner
  end

  private

  def reject_closed_branch_owner
    owner = branch_record_owner
    return unless owner.is_a?(Branch) && owner.closed?

    errors.add(:base, I18n.t('admin.branch_lifecycle.errors.closed_readonly'))
  end

  def branch_record_owner
    if respond_to?(:addressable)
      addressable
    elsif respond_to?(:phoneable)
      phoneable
    elsif respond_to?(:notable)
      notable
    elsif respond_to?(:branch)
      branch
    end
  end
end
