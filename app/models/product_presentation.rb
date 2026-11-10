# frozen_string_literal: true

class ProductPresentation < ApplicationRecord
  include CommercialTenant

  attr_accessor :client_key

  belongs_to :product, inverse_of: :product_presentations
  has_many :product_barcodes, dependent: :restrict_with_error
  has_many :price_list_items, dependent: :restrict_with_error
  validates :name, presence: true, length: { maximum: 100 }
  validates :units, numericality: { greater_than: 0, less_than: 1_000_000_000 }
  enum :status, { active: 'active', inactive: 'inactive' }, validate: true, default: :active
  before_validation :inherit_organization
  validate :same_organization

  private

  def inherit_organization
    self.organization ||= product&.organization
  end

  def same_organization
    validate_commercial_parent(product, :product)
  end
end
