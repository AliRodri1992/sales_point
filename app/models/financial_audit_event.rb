# frozen_string_literal: true

class FinancialAuditEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :actor, class_name: 'User', optional: true
  validates :event, :subject_type, :subject_id, presence: true

  def self.record!(organization:, actor:, event:, subject:, details: {})
    raise ArgumentError, 'Cross-organization financial audit' if subject.organization_id != organization.id

    create!(organization:, actor:, event:, subject_type: subject.class.name, subject_id: subject.id,
            details: details.except('clabe', 'account_number', :clabe, :account_number))
  end

  def readonly?
    persisted?
  end

  before_destroy { throw(:abort) }
end

