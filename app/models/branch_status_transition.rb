# frozen_string_literal: true

# Immutable lifecycle audit trail. This is distinct from deletion (deleted_at).
class BranchStatusTransition < ApplicationRecord
  belongs_to :branch
  belongs_to :changed_by, class_name: 'User', optional: true

  validates :to_status, presence: true, inclusion: { in: %w[preparing active suspended closed] }
  validates :from_status, inclusion: { in: %w[preparing active suspended closed] }, allow_nil: true
  validates :reason, length: { maximum: 2000 }
  validate :reason_required_for_manual_transition

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def reason_required_for_manual_transition
    errors.add(:reason, :blank) if changed_by_id.present? && reason.blank?
  end

  def prevent_mutation
    errors.add(:base, I18n.t('admin.branch_lifecycle.audit_immutable'))
    throw :abort
  end
end
