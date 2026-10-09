# frozen_string_literal: true

class SystemRolePermission < ApplicationRecord
  belongs_to :system_role
  belongs_to :permission

  validates :permission_id, uniqueness: { scope: :system_role_id }
end
