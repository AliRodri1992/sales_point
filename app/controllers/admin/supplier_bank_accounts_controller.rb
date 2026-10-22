# frozen_string_literal: true

module Admin
  class SupplierBankAccountsController < ApplicationController
    include FinancialAccess

    before_action :set_supplier
    before_action :set_account, only: %i[edit update destroy reveal]

    def index
      authorize @supplier.supplier_bank_accounts.new(organization: current_organization), :index?
      scope = policy_scope(@supplier.supplier_bank_accounts.active)
      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
        scope = scope.where('bank_name ILIKE :term OR holder_name ILIKE :term', term:)
      end
      scope = scope.where(currency_code: params[:currency]) if params[:currency].present?
      @currencies = @supplier.supplier_bank_accounts.active.distinct.order(:currency_code).pluck(:currency_code)
      @accounts_total = scope.count
      @accounts_pages = [(@accounts_total.to_f / 8).ceil, 1].max
      @accounts_page = params[:page].to_i.clamp(1, @accounts_pages)
      @accounts = scope.includes(:sat_bank).order(primary: :desc, id: :desc)
                       .limit(8).offset((@accounts_page - 1) * 8)
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
