# frozen_string_literal: true

module SupplierFormAuthorization
  private

  def authorize_nested_sections!(attributes)
    authorize @supplier, :manage_contacts? if attributes.key?(:contacts_attributes)
    authorize @supplier, :manage_addresses? if attributes.key?(:addresses_attributes)
    authorize @supplier, :create_documents? if attributes.key?(:documents)
  end

  def authorize_sensitive_fields!(attributes)
    fiscal = %w[rfc foreign_tax_id sat_fiscal_regime_id person_type]
    commercial = %w[currency_id credit_days credit_limit discount_percent minimum_order_amount]
    keys = attributes.keys.map(&:to_s)
    authorize @supplier, :manage_fiscal? if keys.intersect?(fiscal)
    authorize @supplier, :manage_commercial? if keys.intersect?(commercial)
  end
end
