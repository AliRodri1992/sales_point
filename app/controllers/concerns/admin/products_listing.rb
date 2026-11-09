module Admin
  module ProductsListing
    PER_PAGE = 10
    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS
    SORT_DIRECTIONS = %w[asc desc].freeze

    SORTABLE_COLUMNS = %w[
      products.name products.code products.price
      products.cost products.created_at products.updated_at products.position
    ].freeze

    private

    def refresh_product_catalog(action)
      load_products
      notify_product(current_user, @product, action)
      broadcast_products_update
    end

    def broadcast_products_update
      stream = current_organization ? "products_catalog_#{current_organization.id}" : 'products_catalog'
      Turbo::StreamsChannel.broadcast_refresh_to(stream)
    end

    def load_products
      @products = filter_scope(accessible_products)
      @total_count = @products.count
      @products = apply_sorting(@products)
      @products = paginate(@products).includes(:category, image_attachment: :blob)
    end

    def filter_scope(scope)
      scope = apply_search_filter(scope)
      scope = apply_featured_filter(scope)
      scope = apply_status_filter(scope)
      scope = scope.where(category_id: params[:category_id]) if params[:category_id].to_s.match?(/\A[1-9]\d*\z/)
      if Product.tracking_modes.key?(params[:tracking_mode])
        scope = scope.where(tracking_mode: params[:tracking_mode])
      end
      apply_stock_filter(apply_price_filter(scope))
    end

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      query = "%#{Product.sanitize_sql_like(params[:search].to_s.strip)}%"
      alternate_codes = ProductBarcode.where('value ILIKE ?', query).select(:product_id)
      variants = ProductVariant.where('sku ILIKE :q OR name ILIKE :q', q: query).select(:product_id)
      scope.where('name ILIKE :q OR code ILIKE :q OR sku ILIKE :q OR barcode ILIKE :q', q: query)
           .or(scope.where(id: alternate_codes)).or(scope.where(id: variants))
    end

    def apply_featured_filter(scope)
      return scope unless %w[true false].include?(params[:featured])

      scope.where(featured: params[:featured] == 'true')
    end

    def apply_status_filter(scope)
      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_price_filter(scope)
      min_price = filter_price(params[:min_price])
      max_price = filter_price(params[:max_price])
      scope = scope.where('products.price >= ?', min_price) if min_price
      scope = scope.where('products.price <= ?', max_price) if max_price
      scope
    end

    def filter_price(value)
      return if value.blank?

      number = BigDecimal(value.to_s, exception: false)
      number if number&.finite? && number >= 0
    end

    def apply_stock_filter(scope)
      return scope unless current_organization

      inventories = Inventory.where(organization_id: current_organization.id)
      case params[:stock_status]
      when 'available'
        scope.where(id: inventories.where('stock > 0').select(:product_id))
      when 'out'
        scope.where.not(id: inventories.where('stock > 0').select(:product_id))
      when 'low'
        scope.where(id: inventories.low_stock.select(:product_id))
      else
        scope
      end
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'products.name'
      sort_direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction, 'products.id' => :asc)
    end

    def paginate(scope)
      page = params[:page].to_s.to_i
      page = 1 if page < 1
      per_page = per_page_param
      @per_page = per_page

      @total_pages = (scope.count / per_page.to_f).ceil
      @total_pages = 1 if @total_pages < 1
      page = @total_pages if page > @total_pages

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      table_page_size_for('products')
    end
  end
end
