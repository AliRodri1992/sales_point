# frozen_string_literal: true

module Admin
  class SupplierAddressesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_address, only: %i[edit update destroy]

    def index
      @addresses = @supplier.addresses.not_deleted.order(created_at: :desc)
    end

    def new
      @address = @supplier.addresses.new
    end

    def edit; end

    def create
      @address = @supplier.addresses.new(address_params)
      if @address.save
        redirect_to admin_supplier_addresses_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @address.update(address_params)
        redirect_to admin_supplier_addresses_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @address.update!(deleted_at: Time.current)
      redirect_to admin_supplier_addresses_path(@supplier), notice: t('admin.supplier_details.deleted')
    end

    private

    def set_supplier
      head :forbidden and return unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, :show?
    end

    def set_address
      @address = @supplier.addresses.not_deleted.find(params[:id])
    end

    def address_params
      params.expect(address: %i[street exterior_number interior_number neighborhood city state country postal_code])
    end
  end
end
