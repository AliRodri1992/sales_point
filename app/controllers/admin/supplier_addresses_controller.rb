# frozen_string_literal: true

module Admin
  class SupplierAddressesController < ApplicationController
    include SupplierAuditTrail

    ACTION_POLICY = {
      'index' => :view_addresses?, 'new' => :manage_addresses?, 'create' => :manage_addresses?,
      'edit' => :manage_addresses?, 'update' => :manage_addresses?,
      'destroy' => :manage_addresses?, 'restore' => :manage_addresses?,
      'set_primary' => :manage_addresses?
    }.freeze

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_address, only: %i[edit update destroy set_primary]

    def index
      @address_page = build_address_page
      return render_address_results if request.xhr?

      @active_addresses_count = @supplier.addresses.not_deleted.count
      @deleted_addresses_count = @supplier.addresses.with_deleted.where.not(deleted_at: nil).count
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
      return render :new, status: :unprocessable_content unless apply_confirmation

      if @address.save
        enqueue_geocoding(@address)
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
      @address.assign_attributes(address_params)
      return render :edit, status: :unprocessable_content unless apply_confirmation

      if @address.save
        enqueue_geocoding(@address) if @address.saved_changes.keys.intersect?(Address::GEOGRAPHIC_FIELDS)
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
        @address = record
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

    def set_primary
      if Suppliers::SetPrimaryAddress.new(supplier: @supplier, address: @address).call
        @address.reload
        notify_address('address_updated')
      end

      redirect_to primary_redirect_path, flash: {
        swal_message: t('admin.supplier_details.address_primary_updated')
      }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to primary_redirect_path, alert: t('admin.supplier_details.address_primary_error')
    end

    private

    def primary_redirect_path
      return admin_supplier_path(@supplier, tab: 'addresses') if params[:source] == 'dossier'

      admin_supplier_addresses_path(@supplier)
    end

    def build_address_page
      Suppliers::DossierAddressesPage.new(
        supplier: @supplier, status: params[:status], page: params[:page],
        query: params[:q], filter: params[:filter]
      ).call
    end

    def render_address_results
      set_address_page_headers
      render partial: 'address_cards', locals: address_result_locals
    end

    def set_address_page_headers
      response.headers['X-Next-Page'] = @address_page.next_page.to_s
      response.headers['X-Addresses-Count'] = @address_page.total_count.to_s
      response.headers['X-Addresses-Filter-Counts'] = @address_page.filter_counts.to_json
      response.headers['Cache-Control'] = 'private, no-store'
    end

    def address_result_locals
      { addresses: @address_page.addresses, can_manage_addresses: policy(@supplier).manage_addresses? }
    end

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, ACTION_POLICY.fetch(action_name)
    end

    def set_address = (@address = @supplier.addresses.not_deleted.find(params[:id]))

    def notify_address(action)
      Suppliers::NotifyService.call(action: action, supplier: @supplier, user: current_user, subject: @address)
    end

    def redirect_success(action)
      redirect_to admin_supplier_addresses_path(@supplier),
                  flash: { swal_message: t("admin.supplier_details.#{action}", name: @supplier.name) }
    end

    def load_countries = (@countries = Country.active.ordered)

    def enqueue_geocoding(address)
      return if address.location_confirmed?

      GeocodeAddressJob.perform_later(address.id, address.geocoding_fingerprint)
    end

    def apply_confirmation
      return true unless params.dig(:address, :location_confirmed) == '1'

      coords = params.expect(address: %i[latitude longitude location_signature]).to_h
      signature = Rails.application.message_verifier('supplier-address-location')
                       .verified(coords['location_signature'])
      unless signature == @address.geocoding_fingerprint
        @address.errors.add(:base, :invalid_location_confirmation)
        return false
      end

      @address.assign_attributes(
        latitude: coords['latitude'], longitude: coords['longitude'],
        location_confirmed_at: Time.current, geocoding_status: 'success'
      )
      true
    end

    def address_params
      fields = %i[street exterior_number interior_number neighborhood city state country_id postal_code
                  primary purpose reference_notes]
      params.expect(address: fields)
    end
  end
end
