# frozen_string_literal: true

module Admin
  class SupplierBankAccountsController < ApplicationController
    include FinancialAccess

    before_action :set_supplier
    before_action :set_account, only: %i[edit update destroy reveal]

    def index
      authorize @supplier.supplier_bank_accounts.new(organization: current_organization), :index?
      @accounts = policy_scope(@supplier.supplier_bank_accounts.active).order(primary: :desc, id: :desc)
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
      @account = @supplier.supplier_bank_accounts.active.find(params[:id])
    end

    def load_banks
      @banks = SatBank.current.order(:name)
    end

    def bank_params
      params.expect(supplier_bank_account: %i[
                      sat_bank_code bank_name holder_name
                      account_number clabe currency_code primary
                    ])
    end

    def assign_bank_details
      attributes = bank_params
      @account.assign_attributes(attributes.except(:account_number, :clabe))
      @account.account_number = attributes[:account_number] if attributes[:account_number].present?
      @account.clabe = attributes[:clabe] if attributes[:clabe].present?
    end

    def save_account
      SupplierBankAccount.transaction do
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
