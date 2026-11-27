require 'cgi'

module Admin
  module ProductsLookup
    private

    def accessible_products
      scope = Product.not_deleted
      return scope unless respond_to?(:current_organization, true)
      return scope.where(organization_id: nil) unless current_organization

      scope.where(organization_id: current_organization.id)
    end

    def set_product
      @product = find_product_by_id_or_slug(params[:id])
      raise ActiveRecord::RecordNotFound, 'Product not found' unless @product
    end

    def find_product_by_id_or_slug(id_param)
      return accessible_products.find_by(id: id_param) if id_param.to_s.match?(/\A\d+\z/)

      find_product_by_code(id_param)
    end

    def find_product_by_code(id_param)
      value = CGI.unescape(id_param.to_s)
      matches = accessible_products
                .where('LOWER(slug) = LOWER(:value) OR LOWER(code) = LOWER(:value)', value:)
                .limit(2).to_a
      matches.first if matches.one?
    end

    def product_not_found(exception = nil)
      Rails.logger.error "Product not found: #{exception&.message}"
      redirect_back_or_to(admin_products_path, alert: t('admin.products.index.not_found'))
    end

    def handle_destroy_error(exception)
      Rails.logger.error "Error deleting product #{params[:id]}: #{exception.message}"
      flash[:incident_origin] = Rails.application.message_verifier(:incident_origin).generate(
        product_incident_origin, expires_in: 12.hours
      )
      redirect_back_or_to(admin_products_path, alert: t('admin.products.destroy_failed'))
    end

    def product_incident_origin
      {
        user_id: current_user.id,
        organization_id: current_organization.id,
        screen: 'admin/products#show',
        request_id: request.request_id,
        path: admin_products_path
      }
    end
  end
end
