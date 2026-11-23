# frozen_string_literal: true

module CommercialBreadcrumbsHelper
  private

  def price_list_breadcrumb_items
    commercial_breadcrumb_items('price_lists', admin_price_lists_path, method(:admin_price_list_path))
  end

  def promotion_breadcrumb_items
    commercial_breadcrumb_items('promotions', admin_promotions_path, method(:admin_promotion_path))
  end

  def commercial_breadcrumb_items(section, path, detail_path)
    base = { label: t("admin.catalog_design.#{section}"), path: }
    record = controller.view_assigns['record']
    return [base] if params[:action] == 'index'
    return [base, { label: t('admin.catalog_design.new_record') }] unless record&.persisted?

    detail = { label: record.name }
    return [base, detail] unless %w[edit update].include?(params[:action])

    [base, detail.merge(path: detail_path.call(record)), { label: t('admin.catalog_design.edit_record') }]
  end
end
