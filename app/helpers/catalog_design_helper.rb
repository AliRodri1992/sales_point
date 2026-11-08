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
    return if record.errors.empty?

    content_tag(:div, class: 'catalog-error', role: 'alert', tabindex: '-1') do
      safe_join([content_tag(:strong, t('admin.catalog_design.fix_errors')),
                 content_tag(:ul, safe_join(record.errors.full_messages.map { |message| content_tag(:li, message) }))])
    end
  end

  def catalog_field(form, attribute, type: :text_field, label: nil, **options)
    record = form.object
    label ||= t("admin.catalog_design.#{attribute}")
    content_tag(:div, class: 'catalog-field') do
      safe_join([form.label(attribute, label),
                 form.public_send(type, attribute, **options.except(:aria),
                                  aria: options.fetch(:aria, {}).merge(invalid: record.errors[attribute].any?)),
                 error_message_for(record, attribute)])
    end
  end

  def catalog_select(form, attribute, choices, label: nil, include_blank: true)
    label ||= t("admin.catalog_design.#{attribute}")
    content_tag(:div, class: 'catalog-field') do
      safe_join([form.label(attribute, label),
                 form.select(attribute, choices, { include_blank: },
                             aria: { invalid: form.object.errors[attribute].any? }),
                 error_message_for(form.object, attribute)])
    end
  end

  def catalog_reference_choices(scope, selected_id, label: :name)
    records = scope.to_a
    if selected_id.present? && records.none? { |record| record.id == selected_id }
      retained = scope.klass.with_deleted.find_by(id: selected_id)
      records << retained if retained
    end
    records.map { |record| [record.public_send(label), record.id] }
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
