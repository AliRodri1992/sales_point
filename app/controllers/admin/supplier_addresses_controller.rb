# frozen_string_literal: true

module Admin
  class SupplierAddressesController < ApplicationController
    ACTION_POLICY = {
      'index' => :view_addresses?, 'new' => :manage_addresses?, 'create' => :manage_addresses?,
      'edit' => :manage_addresses?, 'update' => :manage_addresses?,
      'destroy' => :manage_addresses?, 'restore' => :manage_addresses?
    }.freeze

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_address, only: %i[edit update destroy]

    def index
      @address = @supplier.addresses.new
      @addresses = @supplier.addresses.not_deleted.order(created_at: :desc)
    end

    def new
      @address = @supplier.addresses.new
      load_countries
    end

    def edit
      load_countries
    end

    def create
      load_countries
      @address = @supplier.addresses.new(address_params)
      if @address.save
        notify_address('address_created')
        redirect_success('address_created')
      else
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @address.errors.add(:primary, :taken)
      render :new, status: :unprocessable_content
    end

    def update
      load_countries
      if @address.update(address_params)
        notify_address('address_updated')
        redirect_success('address_updated')
      else
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @address.errors.add(:primary, :taken)
      render :edit, status: :unprocessable_content
    end

    def restore
      record = @supplier.addresses.with_deleted.where.not(deleted_at: nil).find(params[:id])
      if record.restore_safely
        notify_address('address_restored')
        redirect_success('address_restored')
      else
        redirect_to admin_supplier_addresses_path(@supplier), alert: record.errors.full_messages.to_sentence
      end
    end

    def destroy
      @address.update!(deleted_at: Time.current)
      notify_address('address_deleted')
      redirect_success('address_deleted')
    end

    private

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, ACTION_POLICY.fetch(action_name)
    end

    def set_address
      @address = @supplier.addresses.not_deleted.find(params[:id])
    end

    def notify_address(action)
      Suppliers::NotifyService.call(action: action, supplier: @supplier, user: current_user)
    end

    def redirect_success(action)
      redirect_to admin_supplier_addresses_path(@supplier),
                  flash: { swal_message: t("admin.supplier_details.#{action}", name: @supplier.name) }
    end

    def load_countries
      @countries = Country.active.ordered
    end

    def address_params
      fields = %i[street exterior_number interior_number neighborhood city state country_id postal_code primary purpose]
      params.expect(address: fields)
    end
  end
end
