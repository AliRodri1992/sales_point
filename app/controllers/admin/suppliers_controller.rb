# frozen_string_literal: true

module Admin
  class SuppliersController < ApplicationController
    include SupplierAuditTrail

    include Pundit::Authorization
    include SuppliersListing
    include SuppliersExporting
    include SuppliersFormHelpers
    include SupplierContactsPagination
    include SupplierAddressesPagination
    include SupplierDossierLoading
    include SupplierFiscalAddressValidation

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_supplier_organization!
    before_action :set_supplier, only: %i[show contacts_page addresses_page edit update destroy]
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def index
      authorize Supplier, :index?
      load_suppliers
      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('supplier_active_filters', partial: 'admin/suppliers/active_filters_frame'),
            turbo_stream.replace('suppliers_list', partial: 'admin/suppliers/list_frame')
          ]
        end
      end
    end

    def show
      authorize @supplier
      load_dossier_sections
    end

    def contacts_page
      render_dossier_contacts_page
    end

    def addresses_page
      render_dossier_addresses_page
    end

    def new
      @supplier = current_organization.suppliers.new
      @supplier.contacts.build
      @supplier.addresses.build(purpose: 'fiscal', primary: true)
      authorize @supplier
      load_fiscal_regimes
      load_reference_catalogs
    end

    def edit
      authorize @supplier
      load_fiscal_regimes
      load_reference_catalogs
      render :new
    end

    def create
      @supplier = build_new_supplier
      authorize @supplier
      authorize_supplier_attributes!(supplier_params)
      return if validate_primary_dossier_submission!(supplier_params, creating: true)

      if @supplier.save
        notify_supplier('created')
        broadcast_suppliers_update
        redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.created') }
      else
        render_supplier_form_error
      end
    rescue ActiveRecord::RecordNotUnique
      render_supplier_duplicate_error
    end

    def update
      authorize @supplier

      attributes = supplier_update_attributes
      authorize_supplier_attributes!(attributes)
      return if validate_primary_dossier_submission!(attributes, creating: false)

      if @supplier.update(attributes)
        notify_supplier('updated')
        broadcast_suppliers_update
        redirect_to supplier_update_destination, flash: { swal_message: t('admin.suppliers.updated') }
      else
        render_supplier_form_error
      end
    rescue ActiveRecord::RecordNotUnique
      render_supplier_duplicate_error
    end

    def destroy
      authorize @supplier
      return redirect_to admin_supplier_path(@supplier), alert: @supplier.errors.full_messages.to_sentence unless
        @supplier.archivable?

      @supplier.update!(deleted_at: Time.current, status: :inactive)
      notify_supplier('destroyed')
      broadcast_suppliers_update
      redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.destroyed') }
    end

    def restore
      @supplier = current_organization.suppliers.where.not(deleted_at: nil).find(params[:id])
      authorize @supplier, :restore?
      if @supplier.update(deleted_at: nil, status: :inactive)
        notify_supplier('updated')
        broadcast_suppliers_update
        redirect_to admin_suppliers_path(archived: '1'), notice: t('admin.suppliers.lifecycle.restored')
      else
        redirect_to admin_suppliers_path(archived: '1'), alert: @supplier.errors.full_messages.to_sentence
      end
    rescue ActiveRecord::RecordNotUnique
      redirect_to admin_suppliers_path(archived: '1'), alert: t('admin.suppliers.lifecycle.restore_conflict')
    end

    private

    def require_supplier_organization!
      head :forbidden unless current_organization
    end

    def set_supplier
      @supplier = policy_scope(
        current_organization.suppliers.not_deleted.includes(:sat_fiscal_regime)
      ).find(params[:id])
    end

    def supplier_params
      params.expect(
        supplier: [
          *supplier_scalar_attributes,
          {
            contacts_attributes: [%i[id name position email phone mobile_phone primary active notes _destroy]],
            addresses_attributes: [%i[
              id street exterior_number interior_number neighborhood city state country_id postal_code
              purpose primary _destroy
            ]],
            documents: []
          }
        ]
      )
    end

    def user_not_authorized
      redirect_to admin_suppliers_path, status: :forbidden,
                                        alert: t('admin.suppliers.errors.unauthorized')
    end
  end
end
