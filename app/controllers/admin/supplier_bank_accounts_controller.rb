# frozen_string_literal: true

module Admin
  class SupplierBankAccountsController < ApplicationController
    include FinancialAccess
    include SupplierBankAccountCreationGuard
    include SupplierBankAccountListing

    before_action :set_supplier
    before_action :require_available_supplier, only: %i[new create]
    before_action :set_account, only: %i[edit update destroy reveal restore review]

    def index
      authorize @supplier.supplier_bank_accounts.new(organization: current_organization), :index?
      load_account_listing
    end

    def new
      @account = @supplier.supplier_bank_accounts.new(organization: current_organization)
      authorize @account
      load_banks
    end

    def edit
      authorize @account
      load_banks
    end

    def create
      attributes = bank_params.except(:status, :blocked_reason)
      attributes[:organization] = current_organization
      attributes[:status] = 'active'
      attributes[:verification_status] = 'pending'
      @account = @supplier.supplier_bank_accounts.new(attributes)
      authorize @account
      if save_account
        redirect_to admin_supplier_bank_accounts_path(@supplier)
      else
        load_banks
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @account
      assign_bank_details
      if save_account
        redirect_to admin_supplier_bank_accounts_path(@supplier)
      else
        load_banks
        render :edit, status: :unprocessable_content
      end
    end

    def review
      authorize @account, :review?
      decision = params[:decision].to_s
      unless %w[verified rejected pending].include?(decision) && @account.status == 'active'
        return redirect_to admin_supplier_bank_accounts_path(@supplier),
                           alert: t('admin.supplier_bank_details.status')
      end

      return invalid_verification_date if decision == 'verified' && verified_bank_date.nil?

      save_review!(decision)
      redirect_to admin_supplier_bank_accounts_path(@supplier)
    end

    def destroy
      authorize @account
      @account.update!(deleted_at: Time.current, primary: false)
      FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                  event: 'bank_account.archived', subject: @account)
      redirect_to admin_supplier_bank_accounts_path(@supplier)
    end

    def restore
      authorize @account, :restore?
      @supplier.with_lock { @account.update!(deleted_at: nil, primary: false) }
      FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                  event: 'bank_account.restored', subject: @account)
      redirect_to admin_supplier_bank_accounts_path(@supplier, archived: '1')
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to admin_supplier_bank_accounts_path(@supplier, archived: '1'),
                  alert: t('admin.supplier_archive.restore_conflict')
    end

    def reveal
      authorize @account
      response.headers['Cache-Control'] = 'no-store'
      render json: @account.reveal!(actor: current_user)
    end

    private

    def invalid_verification_date
      redirect_to admin_supplier_bank_accounts_path(@supplier),
                  alert: t('admin.supplier_bank_details.verification_date_required')
    end

    def save_review!(decision)
      verification_date = verified_bank_date if decision == 'verified'
      attributes = { verification_status: decision }
      attributes[:verified_at] = verification_date.in_time_zone if verification_date
      @account.update!(attributes)
      FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                  event: 'bank_account.verification_reviewed', subject: @account,
                                  details: { decision: decision, verified_on: verification_date&.iso8601 })
    end

    def verified_bank_date
      date = Date.iso8601(params[:verified_on].to_s)
      date unless date.future?
    rescue Date::Error
      nil
    end

    def set_supplier
      @supplier = current_organization.suppliers.not_deleted.find(params[:supplier_id])
    end

    def set_account
      @account = if action_name == 'restore'
                   @supplier.supplier_bank_accounts.with_deleted.where.not(deleted_at: nil).find(params[:id])
                 else
                   @supplier.supplier_bank_accounts.active.find(params[:id])
                 end
    end

    def load_banks = (@banks = SatBank.current.order(:name))

    def bank_params
      sensitive_fields = %i[sat_bank_code bank_name holder_name clabe]
      status_fields = %i[currency_code primary account_type status blocked_reason]
      attributes = params.expect(supplier_bank_account: sensitive_fields + status_fields)
      attributes[:sat_bank_code] = attributes[:sat_bank_code].presence if attributes.key?(:sat_bank_code)
      attributes
    end

    def assign_bank_details
      attributes = bank_params
      @account.assign_attributes(attributes.except(:clabe))
      @account.clabe = attributes[:clabe] if attributes[:clabe].present?
    end

    def save_account
      @supplier.with_lock do
        if @account.primary? && @account.status == 'active'
          @supplier.supplier_bank_accounts.active.where.not(id: @account.id).where(primary: true)
                   .find_each { |previous| previous.update!(primary: false) }
        end
        @account.save!
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'bank_account.saved', subject: @account)
      end
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      false
    end
  end
end
