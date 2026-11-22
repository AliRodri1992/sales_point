# frozen_string_literal: true

module ProductListingHelper
  def product_sort_state(column)
    sort = Admin::ProductsListing::SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'products.name'
    return 'none' unless sort == column

    params[:direction] == 'desc' ? 'descending' : 'ascending'
  end

  def product_sort_link(column, label)
    direction = product_sort_state(column) == 'ascending' ? 'desc' : 'asc'
    query = request.query_parameters.except('page').merge('sort' => column, 'direction' => direction)
    action = t("admin.catalog_directory.#{direction}")
    description = "#{t('admin.catalog_directory.sort_by')}: #{label} · #{action}"

    link_to admin_products_path(query), class: 'products-sort-link',
                                        data: { turbo_frame: '_top' }, aria: { label: description } do
      safe_join([tag.span(label), product_sort_arrows])
    end
  end

  private

  def product_sort_arrows
    tag.span(class: 'products-sort-arrows', aria: { hidden: true }) do
      safe_join([
                  delta_icon('arrow-up', class: 'products-sort-arrow--asc', aria: { hidden: true }),
                  delta_icon('arrow-down', class: 'products-sort-arrow--desc', aria: { hidden: true })
                ])
    end
  end
end
