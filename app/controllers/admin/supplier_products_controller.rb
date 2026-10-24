# frozen_string_literal: true

module Admin
  class SupplierProductsController < ApplicationController
    include SupplierAuditTrail
    include SupplierProductPreferences

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_offer, if: :supplier_offer_action?

    OFFERS_PER_PAGE = 6

    def index
      authorize @supplier, :view_products?

      @search = params[:q].to_s.strip.first(120)
      paginate_offers(filtered_offers)
    end

    def history
      authorize @supplier, :view_products?
      @price_history = @offer.price_history.includes(:currency, :recorded_by).order(created_at: :desc)
    end

    def new
      authorize @supplier, :manage_products?
      @offer = @supplier.supplier_products.new(currency: @supplier.currency, organization: current_organization)
      load_catalogs
    end

    def edit
      authorize @supplier, :manage_products?
      load_catalogs
    end

    def create
      authorize @supplier, :manage_products?
      @offer = @supplier.supplier_products.new(offer_params)
      @offer.organization = current_organization
      @offer.product = organization_products.find(offer_params[:product_id])
      if @offer.save
        redirect_to admin_supplier_supplier_products_path(@supplier), notice: t('admin.procurement.saved')
      else
        load_catalogs
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate
    end

    def update
      authorize @supplier, :manage_products?
      if @offer.update(offer_params.except(:product_id))
        redirect_to admin_supplier_supplier_products_path(@supplier), notice: t('admin.procurement.saved')
      else
        load_catalogs
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate
    end

    def destroy
      authorize @supplier, :manage_products?
      @offer.update!(deleted_at: Time.current, active: false)
      redirect_to admin_supplier_supplier_products_path(@supplier), notice: t('admin.procurement.deleted')
    end

    def restore
      authorize @supplier, :manage_products?
      @supplier.with_lock { @offer.update!(deleted_at: nil, active: true) }
      redirect_to admin_supplier_supplier_products_path(@supplier, archived: '1'),
                  notice: t('admin.supplier_archive.restored_offer')
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to admin_supplier_supplier_products_path(@supplier, archived: '1'),
                  alert: t('admin.supplier_archive.restore_conflict')
    end

    private

    def filtered_offers
      scope = @supplier.supplier_products
      scope = params[:archived] == '1' ? scope.with_deleted.where.not(deleted_at: nil) : scope.available
      scope = scope.joins(:product).merge(current_organization.products.not_deleted)
      @search.present? ? filter_offers(scope) : scope
    end

    def paginate_offers(scope)
      @total_offers = scope.count
      @total_pages = [(@total_offers.to_f / OFFERS_PER_PAGE).ceil, 1].max
      @page = params[:page].to_i.clamp(1, @total_pages)
      @offers = scope.order('products.name ASC', 'supplier_products.id ASC')
                     .includes(:currency, product: [:preferred_supplier, { image_attachment: :blob }])
                     .limit(OFFERS_PER_PAGE).offset((@page - 1) * OFFERS_PER_PAGE)
    end

    def filter_offers(scope)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@search)}%"
      scope.where(
        'products.name ILIKE :term OR products.code ILIKE :term OR products.sku ILIKE :term OR ' \
        'supplier_products.supplier_sku ILIKE :term',
        term:
      )
    end

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
    end

    def supplier_offer_action?
      action_name.in?(%w[edit update destroy history restore set_preferred clear_preferred])
    end

    def set_offer
      @offer = if action_name.in?(%w[history restore])
                 @supplier.supplier_products.with_deleted.find(params[:id])
               else
                 @supplier.supplier_products.available.find(params[:id])
               end
      raise ActiveRecord::RecordNotFound if action_name == 'restore' && @offer.deleted_at.nil?
    end

    def organization_products
      current_organization.products.not_deleted
    end

    def load_catalogs
      @products = organization_products.order(:name)
      @currencies = Currency.active.order(:code)
    end

    def offer_params
      params.expect(supplier_product: %i[product_id supplier_sku supplier_barcode presentation_name
                                         units_per_package purchase_price currency_id discount_percent
                                         freight_amount nonrecoverable_tax minimum_quantity lead_time_days
                                         active])
    end

    def render_duplicate
      @offer.errors.add(:base, :taken)
      load_catalogs
      render action_name == 'create' ? :new : :edit, status: :unprocessable_content
    end
  end
end
