# frozen_string_literal: true

module Admin
  module ProductPriceHistory
    private

    def load_price_history
      scope = @product.price_change_events.includes(:actor, :approved_by)
      @total_count = scope.count
      @per_page = table_page_size_for('product_price_history')
      @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
      @current_page = params[:page].to_s.to_i.clamp(1, @total_pages)
      @price_history = scope.order(created_at: :desc, id: :desc)
                            .limit(@per_page).offset((@current_page - 1) * @per_page)
    end
  end
end
