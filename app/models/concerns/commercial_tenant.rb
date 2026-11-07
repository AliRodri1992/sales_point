# frozen_string_literal: true

module CommercialTenant
  extend ActiveSupport::Concern

  included do
    belongs_to :organization
  end

  private

  def validate_commercial_parent(parent, attribute)
    errors.add(attribute, :invalid) unless parent && parent.organization_id == organization_id
  end

  def validate_product_option(option, attribute)
    return if option.nil?
    return if option.organization_id == organization_id && option.product_id == product_id

    errors.add(attribute, :invalid)
  end
end
