# frozen_string_literal: true

class FinancialAuditEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :actor, class_name: 'User', optional: true
  validates :event, :subject_type, :subject_id, presence: true

  def self.record!(organization:, actor:, event:, subject:, details: {})
    raise ArgumentError, 'Cross-organization financial audit' if subject.organization_id != organization.id

    create!(organization:, actor:, event:, subject_type: subject.class.name, subject_id: subject.id,
            details: sanitized_details(details))
  end

  SENSITIVE_KEYS = %w[clabe account_number bank_account routing_number].freeze

  def self.sanitized_details(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, item), result|
        result[key] = SENSITIVE_KEYS.include?(key.to_s) ? '[REDACTED]' : sanitized_details(item)
      end
    when Array
      value.map { |item| sanitized_details(item) }
    else
      value
    end
  end

  def readonly?
    persisted?
  end

  before_destroy { throw(:abort) }
end
