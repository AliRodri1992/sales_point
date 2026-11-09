# frozen_string_literal: true

# Immutable history of changes to an organization's general table preference.
class GeneralSettingAuditEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :actor, class_name: 'User'

  validates :previous_page_size, :new_page_size, inclusion: { in: TablePagePreference::OPTIONS }

  before_update { throw :abort }
  before_destroy { throw :abort }
end
