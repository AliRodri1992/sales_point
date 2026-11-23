# frozen_string_literal: true

class Promotion < ApplicationRecord
  include CommercialTenant
  include CommercialPeriod
  include CommercialCurrency
  include CommercialLifecycle

  CODE_PREFIX = 'PRO'

  belongs_to :price_list, -> { with_deleted }, optional: true, inverse_of: false

  has_many :promotion_conditions, inverse_of: :promotion, dependent: :restrict_with_error
  has_many :promotion_benefits, inverse_of: :promotion, dependent: :restrict_with_error
  has_many :promotion_redemptions, dependent: :restrict_with_error
  accepts_nested_attributes_for :promotion_conditions, allow_destroy: true, reject_if: :all_blank, limit: 20
  accepts_nested_attributes_for :promotion_benefits, allow_destroy: true, reject_if: :all_blank, limit: 10
  validates :name, presence: true, length: { maximum: 100 }
  validates :usage_limit, :customer_limit, numericality: { only_integer: true, in: 1..2_147_483_647 }, allow_nil: true
  validates :maximum_discount, numericality: { greater_than: 0, less_than: 10_000_000_000 }, allow_nil: true
  enum :combination_mode, { best_price: 'best_price', exclusive: 'exclusive' }, validate: true, default: :best_price
  validate :active_promotion_has_benefits
  validate :valid_price_list_target

  def usage_count
    has_attribute?(:usage_count) ? self[:usage_count].to_i : promotion_redemptions.size
  end

  private

  def quota_exhausted?
    usage_limit && usage_count >= usage_limit
  end

  def activation_content?(_at = nil)
    promotion_benefits.any? { |benefit| benefit.deleted_at.nil? && !benefit.marked_for_destruction? }
  end

  def active_promotion_has_benefits
    errors.add(:promotion_benefits, :blank) if active? && !activation_content?
  end

  def valid_price_list_target
    return if price_list_id.nil?

    validate_commercial_parent(price_list, :price_list)
    return unless price_list && will_save_change_to_price_list_id?
    return if price_list.active? && price_list.deleted_at.nil? && price_list.currency == currency

    errors.add(:price_list, :invalid)
  end
end
