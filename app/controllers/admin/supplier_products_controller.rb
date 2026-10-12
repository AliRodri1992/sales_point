# frozen_string_literal: true

module Admin
  class SupplierProductsController < ApplicationController
    include SupplierAuditTrail

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_offer, only: %i[edit update destroy]

    def index
      authorize @supplier, :view_products?
      @offers = @supplier.supplier_products.available.includes(:product, :currency)
      @offers = @offers.order(:product_id)
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
      @offer.update!(deleted_at: Time.current, preferred: false, active: false)
      redirect_to admin_supplier_supplier_products_path(@supplier), notice: t('admin.procurement.deleted')
    end

    private

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
    end

    def set_offer
      @offer = @supplier.supplier_products.available.find(params[:id])
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
                                         preferred active])
    end

    def render_duplicate
      @offer.errors.add(:base, :taken)
      load_catalogs
      render action_name == 'create' ? :new : :edit, status: :unprocessable_content
    end
  end
end
