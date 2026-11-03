# frozen_string_literal: true

class EmailSettingAudit < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :actor, class_name: 'User'

  validates :setting_type, inclusion: { in: %w[branding sender] }
  validates :changeset, presence: true

  before_destroy { throw :abort }

  def self.record!(setting:, actor:, kind:, extra: {})
    changes = setting.saved_changes.except('id', 'created_at', 'updated_at')
    changes.merge!(extra)
    return if changes.empty?

    create!(organization: setting.organization, actor:, setting_type: kind, changeset: changes)
  end
end
