# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :category, optional: true
  belongs_to :sat_unit_key, optional: true
  belongs_to :sat_tax, optional: true

  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { maximum: 50 },
            format: { with: /\A[A-Za-z0-9\-_]+\z/,
                      message: :invalid_format }

  validates :name,
            presence: true,
            length: { maximum: 100 }

  validates :description,
            length: { maximum: 500 }

  validates :sku,
            uniqueness: { case_sensitive: false, allow_nil: true,
                          if: -> { sku.present? } }

  validates :barcode,
            uniqueness: { case_sensitive: false, allow_nil: true,
                          if: -> { barcode.present? } }

  validates :price,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :cost,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :stock,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :min_stock,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :max_stock,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validate :max_stock_greater_than_min_stock, if: -> { min_stock && max_stock }

  enum :status,
       {
         active: 'active',
         inactive: 'inactive'
       },
       validate: true,
       default: 'active'

  after_initialize :set_default_status, if: :new_record?

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { where(status: :active) }
  scope :with_category, -> { includes(:category) }

  def low_stock?
    return false if min_stock.nil? || min_stock.zero?

    stock <= min_stock
  end

  private

  def set_default_status
    self.status ||= 'active'
  end

  def max_stock_greater_than_min_stock
    return if max_stock.nil? || min_stock.nil?

    errors.add(:max_stock, :greater_than_min) if max_stock < min_stock
  end
end
