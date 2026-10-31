# frozen_string_literal: true

module SupplierFormAuthorization
  private

  def authorize_nested_sections!(attributes)
    %i[contacts addresses].each do |section|
      key = :"#{section}_attributes"
      next unless attributes.key?(key)

      authorize @supplier, nested_section_permission(attributes[key], section)
    end
    authorize @supplier, :create_documents? if attributes.key?(:documents)
  end

  def nested_section_permission(nested, section)
    records = nested.respond_to?(:values) ? nested.values : Array(nested)
    action = records.any? { |record| record[:id].present? } ? 'update' : 'create'
    :"#{action}_#{section}?"
  end

  def authorize_sensitive_fields!(attributes)
    fiscal = %w[rfc foreign_tax_id sat_fiscal_regime_id person_type]
    commercial = %w[currency_id credit_days credit_limit discount_percent minimum_order_amount]
    keys = attributes.keys.map(&:to_s)
    authorize @supplier, :manage_fiscal? if keys.intersect?(fiscal)
    authorize @supplier, :manage_commercial? if keys.intersect?(commercial)
  end
end
