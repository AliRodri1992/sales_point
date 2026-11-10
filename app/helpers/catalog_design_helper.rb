# frozen_string_literal: true

module CatalogDesignHelper
  def catalog_heading(title, subtitle, icon: 'squares-2x2', id: nil)
    content_tag(:header, class: 'catalog-card-heading') do
      safe_join([
                  content_tag(:span, delta_icon(icon, class: 'size-5'), class: 'catalog-icon', aria: { hidden: true }),
                  content_tag(:div, safe_join([content_tag(:h2, title, id: id), content_tag(:p, subtitle)]))
                ])
    end
  end

  def catalog_errors(record)
    messages = record.errors[:base].uniq
    return if messages.empty?

    content_tag(:div, class: 'rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700',
                      role: 'alert') do
      safe_join(messages.map { |message| content_tag(:p, message) })
    end
  end

  def catalog_field(form, attribute, type: :text_field, label: nil, **options)
    record = form.object
    label ||= t("admin.catalog_design.#{attribute}")
    error_id = "#{form.field_id(attribute)}_error"
    aria = options.fetch(:aria, {}).merge(invalid: record.errors[attribute].any?)
    aria[:describedby] = error_id if record.errors[attribute].any?
    content_tag(:div, class: 'catalog-field') do
      safe_join([form.label(attribute, label),
                 form.public_send(type, attribute, **options.except(:aria), aria:),
                 error_message_for(record, attribute, error_id:)])
    end
  end

  def catalog_select(form, attribute, choices, label: nil, include_blank: true)
    label ||= t("admin.catalog_design.#{attribute}")
    error_id = "#{form.field_id(attribute)}_error"
    aria = { invalid: form.object.errors[attribute].any? }
    aria[:describedby] = error_id if form.object.errors[attribute].any?
    content_tag(:div, class: 'catalog-field') do
      safe_join([form.label(attribute, label),
                 form.select(attribute, choices, { include_blank: }, aria:),
                 error_message_for(form.object, attribute, error_id:)])
    end
  end

  def catalog_reference_choices(scope, selected_id, label: :name)
    records = scope.to_a
    retained = catalog_retained_reference(scope, selected_id, records)
    records << retained if retained
    records.map { |record| [record.public_send(label), record.id] }
  end

  def catalog_retained_reference(scope, selected_id, records)
    return if selected_id.blank? || records.any? { |record| record.id == selected_id }

    record = scope.klass.with_deleted.find_by(id: selected_id)
    return unless record
    return record unless record.is_a?(Category)

    record if current_organization && record.organization_id == current_organization.id
  end

  def product_money(amount, currency: nil)
    code = currency.presence || product_currency_code
    unit = { 'MXN' => '

  def product_currency_code
    return 'MXN' unless current_organization

    settings = current_organization.organization_settings.active_records.first
    @product_currency_code ||= settings&.base_currency&.code || 'MXN'
  end

  def product_image_form_token(product)
    return unless product.image.attached? && product.image.blob.persisted?
    return product.image.blob.signed_id if product.persisted? && product.attachment_changes['image'].nil?

    Products::ImageUpload.token(product.image.blob, organization: current_organization, user: current_user)
  end

  def catalog_status(active, scope: 'admin.products.statuses')
    content_tag(:span, t("#{scope}.#{active ? 'active' : 'inactive'}"),
                class: "catalog-status #{'catalog-status-inactive' unless active}")
  end
end
, 'USD' => '

  def product_currency_code
    return 'MXN' unless current_organization

    settings = current_organization.organization_settings.active_records.first
    @product_currency_code ||= settings&.base_currency&.code || 'MXN'
  end

  def product_image_form_token(product)
    return unless product.image.attached? && product.image.blob.persisted?
    return product.image.blob.signed_id if product.persisted? && product.attachment_changes['image'].nil?

    Products::ImageUpload.token(product.image.blob, organization: current_organization, user: current_user)
  end

  def catalog_status(active, scope: 'admin.products.statuses')
    content_tag(:span, t("#{scope}.#{active ? 'active' : 'inactive'}"),
                class: "catalog-status #{'catalog-status-inactive' unless active}")
  end
end
, 'EUR' => '€', 'KRW' => '₩' }.fetch(code, '')
    "#{number_to_currency(amount, unit:)} #{code}"
  end

  def product_currency_code
    return 'MXN' unless current_organization

    settings = current_organization.organization_settings.active_records.first
    @product_currency_code ||= settings&.base_currency&.code || 'MXN'
  end

  def product_image_form_token(product)
    return unless product.image.attached? && product.image.blob.persisted?
    return product.image.blob.signed_id if product.persisted? && product.attachment_changes['image'].nil?

    Products::ImageUpload.token(product.image.blob, organization: current_organization, user: current_user)
  end

  def catalog_status(active, scope: 'admin.products.statuses')
    content_tag(:span, t("#{scope}.#{active ? 'active' : 'inactive'}"),
                class: "catalog-status #{'catalog-status-inactive' unless active}")
  end
end
