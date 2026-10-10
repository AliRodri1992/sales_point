module Admin
  module ProductsListing
    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    SORTABLE_COLUMNS = %w[
      products.name products.code products.price products.stock
      products.cost products.created_at products.updated_at products.position
    ].freeze

    private

    def refresh_product_catalog(action)
      load_products
      notify_product(current_user, @product, action)
      broadcast_products_update
    end

    def broadcast_products_update
      total_count = Product.not_deleted.count
      products = Product.not_deleted.with_category.order(:name).limit(PER_PAGE)
      total_pages = [(total_count / PER_PAGE.to_f).ceil, 1].max
      html = render_to_string(partial: 'admin/products/list', formats: [:html],
                              locals: { products:, total_count:, total_pages: })
      Turbo::StreamsChannel.broadcast_update_to('products_catalog',
                                                target: 'admin_products_list', html: html)
    end

    def load_products
      @products = filter_scope(Product.not_deleted)
      @total_count = @products.count
      @products = apply_sorting(@products)
      @products = paginate(@products)
    end

    def filter_scope(scope)
      scope = apply_search_filter(scope)
      scope = apply_featured_filter(scope)
      apply_status_filter(scope)
    end

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      scope.where(
        'name ILIKE :q OR code ILIKE :q OR sku ILIKE :q OR barcode ILIKE :q',
        q: "%#{params[:search]}%"
      )
    end

    def apply_featured_filter(scope)
      return scope if params[:featured].blank?

      scope.where(featured: params[:featured] == 'true')
    end

    def apply_status_filter(scope)
      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'products.name'
      sort_direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction)
    end

    def paginate(scope)
      page = (params[:page] || 1).to_i
      page = 1 if page < 1
      per_page = per_page_param

      @total_pages = (scope.count / per_page.to_f).ceil
      @total_pages = 1 if @total_pages < 1
      page = @total_pages if page > @total_pages

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      per_page = params[:per_page]&.to_i
      PER_PAGE_OPTIONS.include?(per_page) ? per_page : PER_PAGE
    end
  end
end
