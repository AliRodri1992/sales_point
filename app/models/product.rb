# frozen_string_literal: true

class Product < ApplicationRecord
  has_paper_trail only: [:preferred_supplier_id]
  belongs_to :organization
  belongs_to :preferred_supplier, class_name: 'Supplier', optional: true
  has_many :supplier_products, dependent: :restrict_with_exception
  validate :preferred_supplier_is_eligible, if: :will_save_change_to_preferred_supplier_id?
  has_many :inventories, dependent: :restrict_with_exception
  has_many :purchase_order_items, dependent: :restrict_with_exception
  has_many :purchase_request_items, dependent: :restrict_with_exception
  enum :tracking_mode, { none: 'none', lot: 'lot', serial: 'serial' },
       prefix: :tracking, validate: true, default: :none

  belongs_to :category, optional: true
  belongs_to :sat_unit_key, optional: true
  belongs_to :sat_tax, optional: true

  has_one_attached :image

  validates :code,
            presence: true,
            uniqueness: { scope: :organization_id, case_sensitive: false },
            length: { maximum: 50 },
            format: { with: /\A[A-Za-z0-9\-_]+\z/,
                      message: :invalid_format }

  validates :name,
            presence: true,
            length: { maximum: 100 }

  validates :description,
            length: { maximum: 500 }

  validates :sku,
            uniqueness: { scope: :organization_id, case_sensitive: false, allow_nil: true,
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

  def increment_view_count! = update!(view_count: view_count.to_i + 1)

  def to_param = slug.presence

  private

  def preferred_supplier_is_eligible
    return if preferred_supplier_id.nil?

    eligible = preferred_supplier&.organization_id == organization_id &&
               preferred_supplier&.deleted_at.nil? && preferred_supplier&.active? &&
               supplier_products.available.exists?(supplier_id: preferred_supplier_id)
    errors.add(:preferred_supplier, :invalid) unless eligible
  end

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
end
