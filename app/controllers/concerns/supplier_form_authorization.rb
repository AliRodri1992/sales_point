# frozen_string_literal: true

module SupplierFormAuthorization
  private

  def authorize_nested_sections!(attributes)
    %i[contacts addresses].each do |section|
      key = :"#{section}_attributes"
      next unless attributes.key?(key)

      nested_section_permissions(attributes[key], section).each do |permission|
        authorize @supplier, permission
      end
    end
    authorize @supplier, :create_documents? if attributes.key?(:documents)
  end

  def nested_section_permissions(nested, section)
    records = nested.respond_to?(:values) ? nested.values : Array(nested)
    records.filter_map do |record|
      next unless record.respond_to?(:[]) && record.respond_to?(:key?)

      action = nested_record_action(record)
      :"#{action}_#{section}?" if action
    end.uniq
  end

  def nested_record_action(record)
    destroying = ActiveModel::Type::Boolean.new.cast(record[:_destroy])
    return (record[:id].present? ? 'destroy' : nil) if destroying

    record[:id].present? ? 'update' : 'create'
  end

  def authorize_sensitive_fields!(attributes)
    fiscal = %w[rfc foreign_tax_id sat_fiscal_regime_id person_type]
    commercial = %w[currency_id credit_days credit_limit discount_percent minimum_order_amount]
    keys = attributes.keys.map(&:to_s)
    authorize @supplier, :manage_fiscal? if keys.intersect?(fiscal)
    authorize @supplier, :manage_commercial? if keys.intersect?(commercial)
  end
end
