# frozen_string_literal: true

module SupplierBankAccountListing
  private

  def load_account_listing
    @status = normalized_account_status
    accessible = policy_scope(@supplier.supplier_bank_accounts.with_deleted)
    @account_counts = account_status_counts(accessible)
    @bank_options = bank_names(accessible)
    paginate_accounts(filtered_accounts(accessible))
  end

  def normalized_account_status
    return params[:status] if %w[all active archived].include?(params[:status])

    params[:archived] == '1' ? 'archived' : 'all'
  end

  def account_status_counts(scope)
    {
      all: scope.count,
      active: scope.where(deleted_at: nil).count,
      archived: scope.where.not(deleted_at: nil).count
    }
  end

  def bank_names(scope)
    scope.includes(:sat_bank).filter_map { |account| account.sat_bank&.name || account.bank_name }.uniq.sort
  end

  def filtered_accounts(scope)
    scope = accounts_by_status(scope).left_joins(:sat_bank)
    scope = search_accounts(scope) if params[:q].present?
    scope = bank_filtered_accounts(scope) if params[:bank].present?
    scope.distinct
  end

  def accounts_by_status(scope)
    case @status
    when 'active' then scope.where(deleted_at: nil)
    when 'archived' then scope.where.not(deleted_at: nil)
    else scope
    end
  end

  def search_accounts(scope)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
    scope.where(
      'supplier_bank_accounts.bank_name ILIKE :term OR holder_name ILIKE :term OR ' \
      'last_four ILIKE :term OR sat_banks.name ILIKE :term', term:
    )
  end

  def bank_filtered_accounts(scope)
    scope.where(
      'supplier_bank_accounts.bank_name = :name OR sat_banks.name = :name',
      name: params[:bank].to_s.first(120)
    )
  end

  def paginate_accounts(scope)
    @accounts_total = scope.count
    @accounts_pages = [(@accounts_total.to_f / 8).ceil, 1].max
    @accounts_page = params[:page].to_i.clamp(1, @accounts_pages)
    @accounts = scope.includes(:sat_bank).order(primary: :desc, id: :desc)
                     .limit(8).offset((@accounts_page - 1) * 8)
  end
end
