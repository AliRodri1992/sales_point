# frozen_string_literal: true

module Admin
  class SupplierContactsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_contact, only: %i[edit update destroy]

    def index
      @contacts = @supplier.contacts.not_deleted.order(primary: :desc, name: :asc)
    end

    def new
      @contact = @supplier.contacts.new
    end

    def edit; end

    def create
      @contact = @supplier.contacts.new(contact_params)
      if @contact.save
        redirect_to admin_supplier_contacts_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @contact.update(contact_params)
        redirect_to admin_supplier_contacts_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @contact.update!(deleted_at: Time.current, primary: false)
      redirect_to admin_supplier_contacts_path(@supplier), notice: t('admin.supplier_details.deleted')
    end

    private

    def set_supplier
      head :forbidden and return unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, :show?
    end

    def set_contact
      @contact = @supplier.contacts.not_deleted.find(params[:id])
    end

    def contact_params
      params.expect(contact: %i[name position email phone mobile_phone notes primary active])
    end
  end
end
