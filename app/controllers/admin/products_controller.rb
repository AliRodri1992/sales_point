# frozen_string_literal: true

module Admin
  class ProductsController < ApplicationController
    include Admin::ProductsListing
    include Admin::ProductsLookup

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_product, only: %i[show edit update destroy]

    rescue_from ActiveRecord::RecordNotFound, with: :product_not_found

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
        refresh_product_catalog('created')
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
        refresh_product_catalog('updated')
        redirect_to admin_products_path, flash: { swal_message: t('admin.products.updated') }
      else
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @product.errors.add(:sku, :taken)
      render :edit, status: :unprocessable_content
    end

    def destroy
      @product.update!(deleted_at: Time.current, updated_at: Time.current)
      refresh_product_catalog('destroyed')
      redirect_to admin_products_path, flash: { swal_message: t('admin.products.destroyed') }
    rescue ActiveRecord::RecordNotFound
      redirect_back_or_to(admin_products_path, alert: t('admin.products.index.not_found'))
    rescue StandardError => e
      handle_destroy_error(e)
    end

    private

    def product_params
      params.expect(
        product: %i[
          code name description price cost stock min_stock max_stock
          barcode sku category_id sat_unit_key_id sat_tax_id status
          image_url position featured slug view_count
        ]
      ).tap do |p|
        p[:image] = params[:product][:image] if params[:product][:image].present?
      end
    end

    def notify_product(user, product, action)
      ProductNotification
        .with(action: action, record: product, user: user)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end

  end
end
