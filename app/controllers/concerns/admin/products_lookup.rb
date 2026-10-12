require 'cgi'

module Admin
  module ProductsLookup
    private

    def accessible_products
      scope = Product.not_deleted
      return scope.where(organization_id: nil) unless current_organization

      scope.where(organization_id: [nil, current_organization.id])
    end

    def set_product
      @product = find_product_by_id_or_slug(params[:id])
      raise ActiveRecord::RecordNotFound, 'Product not found' unless @product
    end

    def find_product_by_id_or_slug(id_param)
      return accessible_products.find_by(id: id_param) if id_param.to_s.match?(/\A\d+\z/)

      accessible_products.find_by(slug: id_param) || find_product_by_code(id_param)
    end

    def find_product_by_code(id_param)
      search_term = CGI.unescape(id_param)
      accessible_products
        .where('lower(slug) = lower(?)', search_term)
        .or(accessible_products.where(code: search_term.upcase))
        .first
    end

    def product_not_found(exception = nil)
      Rails.logger.error "Product not found: #{exception&.message}"
      redirect_back_or_to(admin_products_path, alert: t('admin.products.index.not_found'))
    end

    def handle_destroy_error(exception)
      Rails.logger.error "Error deleting product #{params[:id]}: #{exception.message}"
      redirect_back_or_to(admin_products_path, alert: t('admin.products.destroy_failed'))
    end
  end
end
