# frozen_string_literal: true

# Admin-only account creation rules. Existing accounts and self-registration
# are not retroactively subjected to the admin role-assignment form.
module UserAdminAccessValidations
  extend ActiveSupport::Concern

  included do
    normalizes :email, with: ->(value) { value.strip.downcase }
    normalizes :username, with: ->(value) { value.strip }

    attr_accessor :admin_role_selection_required, :admin_selected_system_roles, :admin_selected_branch_roles

    validates :email, length: { maximum: 254 }
    validates :username, length: { maximum: 100 }, allow_blank: true

    validate :admin_employee_requires_role, if: :admin_role_selection_required
    validate :selected_language_must_be_available, if: :validate_selected_language?
  end

  private

  def admin_employee_requires_role
    return unless employee?
    return if Array(admin_selected_system_roles).any? || Array(admin_selected_branch_roles).any?

    errors.add(:system_role_ids, :at_least_one)
  end

  def validate_selected_language?
    language_id.present? && (new_record? || will_save_change_to_language_id?)
  end

  def selected_language_must_be_available
    return if Language.selectable.exists?(id: language_id)

    errors.add(:language_id, :unavailable)
  end
end
