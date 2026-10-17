# frozen_string_literal: true

module Suppliers
  # Scopes every page to one supplier and fetches only the cards being displayed.
  class DossierContactsPage
    PAGE_SIZE = 8
    FILTERS = %w[all primary active inactive].freeze

    attr_reader :contacts, :total_count, :next_page, :page, :filter

    def initialize(supplier:, page: 1, query: nil, filter: 'all')
      @supplier = supplier
      @page = [page.to_i, 1].max
      @query = query.to_s.strip.slice(0, 120)
      @filter = FILTERS.include?(filter) ? filter : 'all'
    end

    def call
      relation = @supplier.contacts.not_deleted
      relation = apply_filter(relation)
      relation = apply_search(relation) if @query.present?

      @total_count = relation.count
      rows = relation.order(primary: :desc, name: :asc, id: :asc)
                     .offset((page - 1) * PAGE_SIZE)
                     .limit(PAGE_SIZE + 1).to_a
      @contacts = rows.first(PAGE_SIZE)
      @next_page = page + 1 if rows.size > PAGE_SIZE
      self
    end

    private

    def apply_filter(relation)
      case filter
      when 'primary' then relation.where(primary: true)
      when 'active' then relation.where(active: true)
      when 'inactive' then relation.where(active: false)
      else relation
      end
    end

    def apply_search(relation)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      relation.where(
        'contacts.name ILIKE :term OR contacts.position ILIKE :term OR ' \
        'contacts.email ILIKE :term OR contacts.phone ILIKE :term OR contacts.mobile_phone ILIKE :term',
        term:
      )
    end
  end
end
