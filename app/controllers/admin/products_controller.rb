# frozen_string_literal: true

module Admin
  class ProductsController < ApplicationController
    include Admin::ProductsListing
    include Admin::ProductsLookup
    include Admin::ProductImageAssignment
    include Admin::ProductFormWriting
    include Admin::ProductPricingPreview
    include Admin::ProductPriceHistory

    layout 'admin_dashboard'
    before_action :authenticate_user!
    include CatalogAuthorization
    include CatalogNavigation

    skip_before_action :authorize_catalog_action, only: :quote

    before_action :set_product, only: %i[show edit update destroy]

    rescue_from ActiveRecord::RecordNotFound, with: :product_not_found

    def index
      load_products
    end

    def show
      load_price_history
    end

    def quote
      render_price_quote
    end

    def new
      @product = Product.new
    end

    def edit; end

    def create
      @product = Product.new
      @product.organization = current_organization

      if save_product
        refresh_product_catalog('created')
        return if redirect_without_catalog_listing(@product, :created)

        redirect_to admin_products_path, flash: { swal_message: t('admin.products.created') }
      else
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @product.errors.add(:base, t('admin.catalog_design.identifier_taken'))
      render :new, status: :unprocessable_content
    end

    def update
      if save_product
        refresh_product_catalog('updated')
        return if redirect_without_catalog_listing(@product, :updated, message: product_update_message)

        redirect_to admin_products_path, flash: { swal_message: product_update_message }
      else
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @product.errors.add(:base, t('admin.catalog_design.identifier_taken'))
      render :edit, status: :unprocessable_content
    end

    def destroy
      @product.with_lock { @product.update!(deleted_at: Time.current, updated_at: Time.current) }
      refresh_product_catalog('destroyed')
      return if redirect_without_catalog_listing(@product, :destroyed)

      redirect_to admin_products_path, flash: { swal_message: t('admin.products.destroyed') }
    rescue ActiveRecord::RecordNotFound
      redirect_back_or_to(admin_products_path, alert: t('admin.products.index.not_found'))
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_product_path(@product), alert: e.record.errors.full_messages.to_sentence, status: :see_other
    rescue StandardError => e
      handle_destroy_error(e)
    end

    private

    def notify_product(user, product, action)
      ProductNotification
        .with(action: action, record: product, user: user)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end
  end
end
