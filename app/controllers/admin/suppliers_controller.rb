# frozen_string_literal: true

module Admin
  class SuppliersController < ApplicationController
    include Pundit::Authorization
    include SuppliersListing

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier, only: %i[show edit update destroy]
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def index
      authorize Supplier, :index?
      load_suppliers
    end

    def show
      authorize @supplier
    end

    def new
      @supplier = Supplier.new
      authorize @supplier
      load_fiscal_regimes
    end

    def edit
      authorize @supplier
      load_fiscal_regimes
      render :new
    end

    def create
      @supplier = Supplier.new(supplier_params)
      authorize @supplier

      if @supplier.save
        notify_supplier('created')
        broadcast_suppliers_update
        redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.created') }
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @supplier.errors.add(:base, t('admin.suppliers.errors.duplicate'))
      load_fiscal_regimes
      render :new, status: :unprocessable_content
    end

    def update
      authorize @supplier

      if @supplier.update(supplier_params)
        notify_supplier('updated')
        broadcast_suppliers_update
        redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.updated') }
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @supplier.errors.add(:base, t('admin.suppliers.errors.duplicate'))
      load_fiscal_regimes
      render :new, status: :unprocessable_content
    end

    def destroy
      authorize @supplier
      @supplier.update!(deleted_at: Time.current)
      notify_supplier('destroyed')
      broadcast_suppliers_update
      redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.destroyed') }
    end

    private

    def set_supplier
      @supplier = Supplier.not_deleted.includes(:sat_fiscal_regime).find(params[:id])
    end

    def load_fiscal_regimes
      @fiscal_regimes = SatFiscalRegime.current.order(:code)
    end

    def supplier_params
      params.expect(
        supplier: %i[code name email phone rfc sat_fiscal_regime_id postal_code status notes]
      )
    end

    def notify_supplier(action)
      Suppliers::NotifyService.call(action:, supplier: @supplier, user: current_user)
    end

    def user_not_authorized
      redirect_to admin_suppliers_path, status: :forbidden,
                                        alert: t('admin.suppliers.errors.unauthorized')
    end
  end
end
