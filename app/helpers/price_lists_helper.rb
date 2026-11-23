# frozen_string_literal: true

module PriceListsHelper
  def price_list_status(record)
    status = record.effective_status
    tag.span(t("admin.price_lists_ui.status.#{status}"),
             class: class_names('catalog-status', 'catalog-status-inactive' => status != 'active'),
             data: { price_list_status: status })
  end

  def price_list_editable?(record)
    %w[draft scheduled active paused].include?(record.effective_status) && policy(record).update?
  end

  def price_list_period(record)
    start_time = record.starts_at
    end_time = record.ends_at
    return t('admin.price_lists_ui.open_period') unless start_time || end_time

    days = [start_time, end_time].map { |time| time && l(time.in_time_zone, format: :short) }
    return t('admin.price_lists_ui.from', date: days.first) unless end_time
    return t('admin.price_lists_ui.until', date: days.last) unless start_time

    days.join(' – ')
  end

  def price_list_currency_places
    @price_list_currency_places ||= Currency.with_deleted.pluck(:code, :decimal_places).to_h
  end

  def price_list_money(amount, currency)
    return '—' if amount.nil?

    places = price_list_currency_places.fetch(currency, 2)
    number_to_currency(amount, unit: currency, format: '%n %u', precision: places)
  end

  def price_list_product(item)
    product = item.product
    product if product && product.organization_id == current_organization.id
  end

  def price_list_units(item, product)
    option = item.product_presentation
    option && option.product_id == product&.id ? option.units : 1
  end

  def price_list_base_currency
    @price_list_base_currency ||= product_currency_code
  end

  def price_list_activity_label(event)
    action = event.event.delete_prefix('price_list.')
    labels = { 'create' => 'created', 'update' => 'updated', 'item_retired' => 'item_retired' }
    return t("admin.price_lists_ui.#{labels.fetch(action)}") if labels.key?(action)
    return t("admin.price_lists_ui.actions.#{action}") if %w[activate pause resume duplicate archive].include?(action)

    t('admin.price_lists_ui.changed')
  end

  def price_list_margin(item, product, currency)
    return '—' unless product&.cost && item.price&.positive? && currency == price_list_base_currency

    cost = product.cost * price_list_units(item, product)
    number_to_percentage((item.price - cost) / item.price * 100, precision: 2, strip_insignificant_zeros: true)
  end

  def price_list_filter_values(selected_product)
    values = params.permit(:search, :status, :currency, :customer_segment, :validity).to_h.compact_blank
    values['product_id'] = selected_product.name if selected_product
    { 'status' => price_list_statuses, 'validity' => %w[current upcoming ended] }.each do |field, options|
      value = values.delete(field)
      values[field] = t("admin.price_lists_ui.#{field}.#{value}") if options.include?(value)
    end
    values
  end

  def price_list_statuses
    %w[draft scheduled active paused expired archived]
  end
end
