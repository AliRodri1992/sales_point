# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :category, optional: true
  belongs_to :sat_unit_key, optional: true
  belongs_to :sat_tax, optional: true

  has_one_attached :image

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

  validates :position,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  # Removed image_url validation - now using Active Storage for images

  validates :slug,
            format: { with: /\A[a-z0-9-]+\z/,
                      message: :invalid_format },
            allow_blank: true

  validates :featured,
            inclusion: { in: [true, false] }

  validates :view_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  before_validation :set_defaults, if: :new_record?
  before_validation :set_slug, if: -> { name.present? && slug.blank? }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { where(status: :active) }
  scope :with_category, -> { includes(:category) }
  scope :featured, -> { where(featured: true) }
  scope :by_slug, ->(slug) { where(slug: slug) }
  scope :sorted_by_position, -> { order(position: :asc, name: :asc) }

  def low_stock?
    return false if min_stock.nil? || min_stock.zero?

    stock <= min_stock
  end

  def increment_view_count!
    increment!(:view_count)
  end

  def to_param
    slug.presence
  end

  private

  def set_defaults
    self.status ||= 'active'
    self.position ||= 0
    self.view_count ||= 0
    self.featured = false if featured.nil?
  end

  def set_slug
    return if slug.present?

    self.slug = name.to_s.parameterize(separator: '-')
  end

  def max_stock_greater_than_min_stock
    return if max_stock.nil? || min_stock.nil?

    errors.add(:max_stock, :greater_than_min) if max_stock < min_stock
  end
end