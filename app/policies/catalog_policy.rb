# frozen_string_literal: true

class CatalogPolicy < ApplicationPolicy
  ACTIONS = %i[index show create update destroy].freeze

  class_attribute :permission_prefix

  ACTIONS.each do |action|
    define_method("#{action}?") { permitted_action?(action) }
  end

  private

  def administrator?
    return @administrator if defined?(@administrator)

    @administrator = user&.admin? || false
  end

  def permitted_action?(action)
    @action_permissions ||= {}
    return @action_permissions[action] if @action_permissions.key?(action)

    @action_permissions[action] = user.present? &&
                                  (administrator? || (user.permission?("#{permission_prefix}.access") &&
                                                  user.permission?("#{permission_prefix}.#{action}")))
  end
end
