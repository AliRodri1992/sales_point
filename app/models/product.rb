# frozen_string_literal: true

class Product < ApplicationRecord
  has_paper_trail only: [:preferred_supplier_id]
  belongs_to :organization
  include PreferredSupplierValidation

  has_many :supplier_products, dependent: :restrict_with_exception
  has_many :inventories, dependent: :restrict_with_exception
  has_many :purchase_order_items, dependent: :restrict_with_exception
  has_many :purchase_request_items, dependent: :restrict_with_exception
  enum :tracking_mode, { none: 'none', lot: 'lot', serial: 'serial' },
       prefix: :tracking, validate: true, default: :none

  belongs_to :category, optional: true
  belongs_to :sat_unit_key, optional: true
  belongs_to :sat_tax, optional: true

  has_one_attached :image
  include ProductCommercialCatalog
  include ProductCatalogIntegrity
  include ProductSkuReservation
  include ProductImageValidation

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

  normalizes :sku, with: ->(value) { value.strip.presence }

  validates :sku,
            length: { maximum: 50 },
            uniqueness: { scope: :organization_id, case_sensitive: false, allow_nil: true,
                          if: -> { sku.present? } }

  validates :barcode,
            length: { maximum: 100 },
            uniqueness: { scope: :organization_id, case_sensitive: false, allow_nil: true,
                          if: -> { barcode.present? } }

  validates :price,
            presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }

  validates :cost,
            numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 },
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
  validate :valid_catalog_references
  validate :code_slug_namespace_available

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { where(status: :active) }
  scope :with_category, -> { includes(:category) }
  scope :featured, -> { where(featured: true) }
  scope :by_slug, ->(slug) { where(slug: slug) }
  scope :sorted_by_position, -> { order(position: :asc, name: :asc) }

  def increment_view_count! = update!(view_count: view_count.to_i + 1)

  # Generated links always use IDs; legacy slugs and codes remain readable when unambiguous.
  def to_param = id&.to_s

  private

  def valid_catalog_references
    %i[category sat_unit_key sat_tax].each do |association|
      attribute = "#{association}_id"
      next unless will_save_change_to_attribute?(attribute) && public_send(attribute).present?

      errors.add(attribute, :invalid) unless valid_catalog_reference?(association)
    end
  end

  def valid_catalog_reference?(association)
    reference = public_send(association)
    return false unless reference
    return true unless association == :category

    reference.organization_id == organization_id && reference.active? && reference.deleted_at.nil?
  end

  def code_slug_namespace_available
    return unless organization_id && (will_save_change_to_code? || will_save_change_to_slug?)

    others = self.class.where(organization_id:).where.not(id:)
    validate_shadowed_identifier(others, :code, :slug)
    validate_shadowed_identifier(others, :slug, :code)
  end

  def validate_shadowed_identifier(scope, source, target)
    value = public_send(source)
    return if value.blank?

    errors.add(source, :taken) if scope.exists?(["LOWER(#{target}) = LOWER(?)", value])
  end

  def set_defaults
    self.status ||= 'active'
    self.position ||= 0
    self.view_count ||= 0
    self.featured = false if featured.nil?
  end

  def set_slug
    return if slug.present?

    base = name.to_s.parameterize(separator: '-')
    base = code.to_s.parameterize if base.blank?
    self.slug = slug_collision?(base) ? "#{base}-#{SecureRandom.hex(4)}" : base
  end

  def slug_collision?(value)
    others = self.class.where(organization_id:).where.not(id:)
    others.exists?(['LOWER(slug) = LOWER(?) OR LOWER(code) = LOWER(?)', value, value])
  end
end
