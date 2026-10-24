# frozen_string_literal: true

module Admin
  class SupplierBankAccountsController < ApplicationController
    include FinancialAccess
    include SupplierBankAccountCreationGuard

    before_action :set_supplier
    before_action :require_available_supplier, only: %i[new create]
    before_action :set_account, only: %i[edit update destroy reveal restore]

    def index
      authorize @supplier.supplier_bank_accounts.new(organization: current_organization), :index?
      @status = %w[all active archived].include?(params[:status]) ? params[:status] : status_from_legacy
      accessible = policy_scope(@supplier.supplier_bank_accounts.with_deleted)
      @account_counts = {
        all: accessible.count,
        active: accessible.where(deleted_at: nil).count,
        archived: accessible.where.not(deleted_at: nil).count
      }
      @bank_options = accessible.includes(:sat_bank).map { |record| record.sat_bank&.name || record.bank_name }
                                .compact.uniq.sort
      paginate_accounts(filtered_accounts(accessible))
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

    def paginate_accounts(scope)
      @accounts_total = scope.count
      @accounts_pages = [(@accounts_total.to_f / 8).ceil, 1].max
      @accounts_page = params[:page].to_i.clamp(1, @accounts_pages)
      @accounts = scope.includes(:sat_bank).order(primary: :desc, id: :desc)
                       .limit(8).offset((@accounts_page - 1) * 8)
    end

    def filtered_accounts(accessible)
      scope = case @status
              when 'active' then accessible.where(deleted_at: nil)
              when 'archived' then accessible.where.not(deleted_at: nil)
              else accessible
              end
      scope = scope.left_joins(:sat_bank)
      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
        scope = scope.where(
          'supplier_bank_accounts.bank_name ILIKE :term OR holder_name ILIKE :term OR ' \
          'last_four ILIKE :term OR sat_banks.name ILIKE :term', term:
        )
      end
      if params[:bank].present?
        scope = scope.where('supplier_bank_accounts.bank_name = :name OR sat_banks.name = :name',
                            name: params[:bank].to_s.first(120))
      end
      scope.distinct
    end

    def status_from_legacy
      params[:archived] == '1' ? 'archived' : 'all'
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
      params.expect(supplier_bank_account: %i[
                      sat_bank_code bank_name holder_name
                      account_number clabe currency_code primary
                      card_last_four card_expiration_month card_expiration_year
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
