# frozen_string_literal: true

class OrganizationSetting < ApplicationRecord
  belongs_to :organization

  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :timezone, presence: true
  validates :organization_id, uniqueness: true
end