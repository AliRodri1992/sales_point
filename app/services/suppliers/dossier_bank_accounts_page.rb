# frozen_string_literal: true

module Suppliers
  class DossierBankAccountsPage
    PAGE_SIZE = 8
    STATUSES = %w[all active archived].freeze

    attr_reader :status, :query, :bank, :page, :total_count, :total_pages, :accounts, :counts, :banks

    def initialize(supplier:, query: nil, bank: nil, status: nil, page: nil)
      @supplier = supplier
      @query = query.to_s.strip.first(100)
      @bank = bank.to_s.strip.first(120)
      @status = STATUSES.include?(status) ? status : 'active'
      @page = [page.to_i, 1].max
    end

    def call
      scope = @supplier.supplier_bank_accounts.with_deleted
      load_facets(scope)
      load_results(filtered_scope(scope))
      self
    end

    def from
      return 0 if total_count.zero?

      (page - 1) * PAGE_SIZE + 1
    end

    def to
      [page * PAGE_SIZE, total_count].min
    end

    private

    def load_facets(scope)
      @counts = {
        all: scope.count,
        active: scope.where(deleted_at: nil).count,
        archived: scope.where.not(deleted_at: nil).count
      }
      bank_options = by_status(scope).includes(:sat_bank)
      @banks = bank_options.filter_map { |account| account.sat_bank&.name || account.bank_name }.uniq.sort
    end

    def load_results(scope)
      @total_count = scope.count
      @total_pages = [(@total_count.to_f / PAGE_SIZE).ceil, 1].max
      @page = @page.clamp(1, @total_pages)
      @accounts = scope.includes(:sat_bank).order(primary: :desc, id: :desc)
                       .limit(PAGE_SIZE).offset((@page - 1) * PAGE_SIZE)
    end

    def filtered_scope(scope)
      scope = by_status(scope).left_joins(:sat_bank)
      scope = by_query(scope) if query.present?
      scope = by_bank(scope) if bank.present?
      scope.distinct
    end

    def by_status(scope)
      case status
      when 'active' then scope.where(deleted_at: nil)
      when 'archived' then scope.where.not(deleted_at: nil)
      else scope
      end
    end

    def by_query(scope)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      scope.where(
        'supplier_bank_accounts.bank_name ILIKE :term OR sat_banks.name ILIKE :term OR ' \
        'supplier_bank_accounts.holder_name ILIKE :term OR supplier_bank_accounts.last_four ILIKE :term ' \
        'OR supplier_bank_accounts.card_last_four ILIKE :term', term:
      )
    end

    def by_bank(scope)
      scope.where('supplier_bank_accounts.bank_name = :bank OR sat_banks.name = :bank', bank:)
    end
  end
end
