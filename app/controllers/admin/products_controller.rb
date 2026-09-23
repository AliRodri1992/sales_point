# frozen_string_literal: true

require 'cgi'

module Admin
  class ProductsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_product, only: %i[show edit update destroy]

    rescue_from ActiveRecord::RecordNotFound, with: :product_not_found

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    SORTABLE_COLUMNS = %w[
      products.name products.code products.price products.stock
      products.cost products.created_at products.updated_at products.position
    ].freeze

    SORT_DIRECTIONS = %w[asc desc].freeze

    def index
      load_products
    end

    def show; end

    def new
      @product = Product.new
    end

    def edit; end

    def create
      @product = Product.new(product_params)

      if @product.save
        load_products
        notify_product(current_user, @product, 'created')
        broadcast_products_update
        redirect_to admin_products_path, flash: { swal_message: t('admin.products.created') }
      else
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @product.errors.add(:sku, :taken)
      render :new, status: :unprocessable_content
    end

    def update
      if @product.update(product_params)
        load_products
        notify_product(current_user, @product, 'updated')
        # broadcast_products_update  # Temporarily disabled for debugging
        redirect_to admin_products_path, flash: { swal_message: t('admin.products.updated') }
      else
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @product.errors.add(:sku, :taken)
      render :edit, status: :unprocessable_content
    end

    def destroy
      @product.touch
      @product.update!(deleted_at: Time.current)
      load_products
      notify_product(current_user, @product, 'destroyed')
      # broadcast_products_update  # Temporarily disabled for debugging
      redirect_to admin_products_path, flash: { swal_message: t('admin.products.destroyed') }
    rescue ActiveRecord::RecordNotFound
      redirect_back(fallback_location: admin_products_path, alert: t('admin.products.index.not_found'))
    rescue StandardError => e
      Rails.logger.error "Error deleting product #{params[:id]}: #{e.message}"
      redirect_back(fallback_location: admin_products_path, alert: t('admin.products.destroy_failed'))
    end

    private

    def set_product
      # Try to find by ID first (if numeric), otherwise by slug
      if params[:id].to_s =~ /\A\d+\z/
        @product = Product.not_deleted.find_by(id: params[:id])
      else
        @product = Product.not_deleted.find_by(slug: params[:id])
        # If not found by slug, try fallback search by name/code (for edge cases)
        if @product.nil?
          search_term = CGI.unescape(params[:id])
          @product = Product.not_deleted
                          .where('lower(slug) = lower(?)', search_term)
                          .or(Product.not_deleted.where(code: search_term.upcase))
                          .first
        end
      end
      raise ActiveRecord::RecordNotFound, "Product not found" unless @product
    end

    def product_not_found(exception = nil)
      Rails.logger.error "Product not found: #{exception&.message}"
      redirect_back(fallback_location: admin_products_path, alert: t('admin.products.index.not_found'))
    end

    def product_params
      params.expect(
        product: %i[
          code name description price cost stock min_stock max_stock
          barcode sku category_id sat_unit_key_id sat_tax_id status
          image_url position featured slug view_count
        ]
      )
    end

    def notify_product(user, product, action)
      ProductNotification
        .with(action: action, record: product, user: user)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end

    # Broadcasts a refreshed products catalog to every subscribed client
    # so changes are visible in real-time across devices (not just the
    # requesting client that receives the HTTP turbo_stream response).
    def broadcast_products_update
      total_count = Product.not_deleted.count
      products = Product.not_deleted.with_category.order(:name).limit(PER_PAGE)
      total_pages = [(total_count / PER_PAGE.to_f).ceil, 1].max
      html = render_to_string(partial: 'admin/products/list', formats: [:html],
                              locals: { products:, total_count:, total_pages: })
      Turbo::StreamsChannel.broadcast_update_to('products_catalog',
                                                target: 'products_list', html: html)
    end

    def load_products
      @products = filter_scope(Product.not_deleted)
      @total_count = @products.count
      @products = apply_sorting(@products)
      @products = paginate(@products)
    end

    def filter_scope(scope)
      if params[:search].present?
        scope = scope.where(
          'name ILIKE :q OR code ILIKE :q OR sku ILIKE :q OR barcode ILIKE :q',
          q: "%#{params[:search]}%"
        )
      end

      if params[:featured].present?
        scope = case params[:featured]
                when 'true'
                  scope.where(featured: true)
                when 'false'
                  scope.where(featured: false)
                else
                  scope
                end
      end

      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'products.name'
      sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'

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
