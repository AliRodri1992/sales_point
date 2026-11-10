# frozen_string_literal: true

module Inventories
  class Directory
    STOCK_STATUSES = %w[out low available].freeze
    TRACKING_MODES = %w[none lot serial].freeze

    LOW_STOCK_SQL = 'inventories.stock > 0 AND inventories.min_stock > 0 ' \
                    'AND inventories.stock <= inventories.min_stock'
    AVAILABLE_STOCK_SQL = 'inventories.stock > 0 AND ' \
                          '(inventories.min_stock = 0 OR inventories.stock > inventories.min_stock)'

    SEARCH_SQL = [
      'LOWER(products.name) LIKE :query',
      'LOWER(products.code) LIKE :query',
      "LOWER(COALESCE(products.sku, '')) LIKE :query",
      "LOWER(COALESCE(products.barcode, '')) LIKE :query"
    ].join(' OR ').freeze

    def self.summary(scope)
      {
        records: scope.count,
        stock: scope.sum(:stock),
        out: scope.where(stock: 0).count,
        low: scope.where(LOW_STOCK_SQL).count
      }
    end

    def self.filter(scope, filters)
      scope = search(scope, filters['search']) if filters['search'].present?
      scope = scope.where(products: { tracking_mode: filters['tracking'] }) if filters['tracking'].present?
      filter_stock_status(scope, filters['status'])
    end

    def self.search(scope, term)
      query = "%#{Product.sanitize_sql_like(term.downcase)}%"
      scope.where(SEARCH_SQL, query:)
    end

    def self.filter_stock_status(scope, status)
      case status
      when 'out' then scope.where(stock: 0)
      when 'low' then scope.where(LOW_STOCK_SQL)
      when 'available' then scope.where(AVAILABLE_STOCK_SQL)
      else scope
      end
    end
  end
end
