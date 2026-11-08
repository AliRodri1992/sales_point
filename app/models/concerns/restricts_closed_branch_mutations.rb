# frozen_string_literal: true

# Ensures branch details remain read-only after a permanent closure.
module RestrictsClosedBranchMutations
  extend ActiveSupport::Concern

  included do
    validate :reject_closed_branch_owner
    around_save :serialize_branch_owned_save
    around_destroy :serialize_branch_owned_destroy
    before_destroy :prevent_closed_branch_deletion
  end

  private

  def serialize_branch_owned_save(&)
    with_locked_branch_owner(&)
  end

  def serialize_branch_owned_destroy(&)
    with_locked_branch_owner(&)
  end

  def with_locked_branch_owner
    owner = branch_record_owner
    return yield unless owner.is_a?(Branch) && owner.persisted?

    locked = Branch.with_deleted.find(owner.id)
    locked.with_lock do
      if locked.closed? || locked.deleted_at.present?
        errors.add(:base, I18n.t('admin.branch_lifecycle.errors.closed_readonly'))
        raise ActiveRecord::RecordInvalid, self
      end

      yield
    end
  end

  def reject_closed_branch_owner
    owner = branch_record_owner
    return unless owner.is_a?(Branch) && owner.closed?

    errors.add(:base, I18n.t('admin.branch_lifecycle.errors.closed_readonly'))
  end

  def prevent_closed_branch_deletion
    owner = branch_record_owner
    return unless owner.is_a?(Branch) && owner.closed?

    errors.add(:base, I18n.t('admin.branch_lifecycle.errors.closed_readonly'))
    throw :abort
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
    elsif respond_to?(:inventory)
      inventory&.branch
    elsif respond_to?(:goods_receipt)
      goods_receipt&.branch
    end
  end
end
