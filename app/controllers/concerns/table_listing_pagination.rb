# frozen_string_literal: true

module TableListingPagination
  private

  def paginate_table_listing(scope, table_key:)
    @total_count = scope.count
    @per_page = table_page_size_for(table_key)
    @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
    @current_page = params[:page].to_i.clamp(1, @total_pages)

    scope.limit(@per_page).offset((@current_page - 1) * @per_page)
  end
end
