# frozen_string_literal: true

class Promotion < ApplicationRecord
  include CommercialTenant
  include CommercialPeriod
  include CommercialCurrency
  include CommercialLifecycle

  CODE_PREFIX = 'PRO'
  MAX_CONDITIONS = 20
  MAX_BENEFITS = 10
  # Deleted rows still appear in nested attributes when replacing persisted rows.
  MAX_SUBMITTED_CONDITIONS = MAX_CONDITIONS * 2
  MAX_SUBMITTED_BENEFITS = MAX_BENEFITS * 2

  belongs_to :price_list, -> { with_deleted }, optional: true, inverse_of: false

  has_many :promotion_conditions, inverse_of: :promotion, dependent: :restrict_with_error
  has_many :promotion_benefits, inverse_of: :promotion, dependent: :restrict_with_error
  has_many :promotion_redemptions, dependent: :restrict_with_error
  accepts_nested_attributes_for :promotion_conditions, allow_destroy: true, reject_if: :all_blank,
                               limit: MAX_SUBMITTED_CONDITIONS
  accepts_nested_attributes_for :promotion_benefits, allow_destroy: true,
                               reject_if: :empty_default_benefit?, limit: MAX_SUBMITTED_BENEFITS
  validates :name, presence: true, length: { maximum: 100 }
  validates :usage_limit, :customer_limit, numericality: { only_integer: true, in: 1..2_147_483_647 }, allow_nil: true
  validates :maximum_discount, numericality: { greater_than: 0, less_than: 10_000_000_000 }, allow_nil: true
  enum :combination_mode, { best_price: 'best_price', exclusive: 'exclusive' }, validate: true, default: :best_price
  validate :active_promotion_has_benefits
  validate :valid_price_list_target
  validate :validate_condition_combinations
  validate :validate_live_row_limits
  validate :validate_activation_targets, if: -> { active? && will_save_change_to_status? }

  def usage_count
    has_attribute?(:usage_count) ? self[:usage_count].to_i : promotion_redemptions.size
  end

  private

  # An untouched percentage placeholder must not prevent saving a draft.
  # Persisted benefits and any non-default kind still receive model validation.
  def empty_default_benefit?(attributes)
    attributes['id'].blank? && attributes['value'].blank? && attributes['kind'].to_s == 'percentage'
  end

  def live_conditions
    promotion_conditions.reject { |item| item.marked_for_destruction? || item.deleted_at.present? }
  end

  def live_benefits
    promotion_benefits.reject { |item| item.marked_for_destruction? || item.deleted_at.present? }
  end

  def validate_live_row_limits
    errors.add(:promotion_conditions, :too_many, count: MAX_CONDITIONS) if live_conditions.size > MAX_CONDITIONS
    errors.add(:promotion_benefits, :too_many, count: MAX_BENEFITS) if live_benefits.size > MAX_BENEFITS
  end

  def validate_condition_combinations
    conditions = live_conditions
    conditions.group_by(&:kind).each do |kind, rows|
      next if kind.nil?

      if %w[min_quantity min_subtotal customer_segment].include?(kind)
        errors.add(:promotion_conditions, :repeated_rule) if rows.size > 1
        next
      end

      field = kind.include?('product') ? :product_id : :category_id
      ids = rows.filter_map { |row| row.public_send(field) }
      errors.add(:promotion_conditions, :duplicate_target) if ids.uniq.size != ids.size
    end

    [%w[product excluded_product], %w[category excluded_category]].each do |included, excluded|
      field = included == 'product' ? :product_id : :category_id
      selected = conditions.select { |condition| condition.kind == included }
                           .filter_map { |condition| condition.public_send(field) }
      rejected = conditions.select { |condition| condition.kind == excluded }
                           .filter_map { |condition| condition.public_send(field) }
      errors.add(:promotion_conditions, :contradictory_target) if (selected & rejected).any?
    end
  end

  def quota_exhausted?
    usage_limit && usage_count >= usage_limit
  end

  def activation_content?(_at = nil)
    live_benefits.any? && activation_targets_available?
  end

  def activation_targets_available?
    live_conditions.all? do |condition|
      target = case condition.kind
               when 'product', 'excluded_product' then condition.product
               when 'category', 'excluded_category' then condition.category
               end
      next true if %w[min_quantity min_subtotal customer_segment].include?(condition.kind)

      target && target.active? && target.deleted_at.nil? && target.organization_id == organization_id
    end && (price_list_id.nil? || usable_activation_price_list?)
  end

  def usable_activation_price_list?
    price_list && price_list.active? && price_list.deleted_at.nil? &&
      price_list.organization_id == organization_id && price_list.currency == currency
  end

  def validate_activation_targets
    errors.add(:promotion_conditions, :unavailable_target) unless activation_targets_available?
  end

  def active_promotion_has_benefits
    errors.add(:promotion_benefits, :blank) if active? && live_benefits.empty?
  end

  def valid_price_list_target
    return if price_list_id.nil?

    validate_commercial_parent(price_list, :price_list)
    return unless price_list && will_save_change_to_price_list_id?
    return if price_list.active? && price_list.deleted_at.nil? && price_list.currency == currency

    errors.add(:price_list, :invalid)
  end
end
