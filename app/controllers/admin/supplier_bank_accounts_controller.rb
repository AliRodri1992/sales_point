# frozen_string_literal: true

module Admin
  class SupplierBankAccountsController < ApplicationController
    include FinancialAccess
    include SupplierBankAccountCreationGuard
    include SupplierBankAccountListing

    before_action :set_supplier
    before_action :require_available_supplier, only: %i[new create]
    before_action :set_account, only: %i[edit update destroy reveal restore]

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
      @account = @supplier.supplier_bank_accounts.new(bank_params.merge(organization: current_organization))
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

    def destroy
      authorize @account
      @account.update!(deleted_at: Time.current, primary: false)
      FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                  event: 'bank_account.archived', subject: @account)
      redirect_to admin_supplier_bank_accounts_path(@supplier)
    end

    def restore
      authorize @account, :update?
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
      attributes = params.expect(supplier_bank_account: %i[
                      sat_bank_code bank_name holder_name
                      account_number clabe currency_code primary
                      card_last_four card_expiration_month card_expiration_year
                    ])
      attributes[:sat_bank_code] = attributes[:sat_bank_code].presence if attributes.key?(:sat_bank_code)
      attributes
    end

    def assign_bank_details
      attributes = bank_params
      @account.assign_attributes(attributes.except(:account_number, :clabe))
      @account.account_number = attributes[:account_number] if attributes[:account_number].present?
      @account.clabe = attributes[:clabe] if attributes[:clabe].present?
    end

    def save_account
      @supplier.with_lock do
        if @account.primary?
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
