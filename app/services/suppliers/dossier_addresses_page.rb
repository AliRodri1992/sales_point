# frozen_string_literal: true

module Suppliers
  # Paginates the addresses of one supplier, including type counts for filter chips.
  class DossierAddressesPage
    PAGE_SIZE = 8
    FILTERS = %w[all fiscal delivery commercial general primary confirmed approximate pending failed].freeze

    attr_reader :addresses, :total_count, :next_page, :page, :filter, :filter_counts, :status

    def initialize(supplier:, page: 1, query: nil, filter: 'all', status: 'active')
      @supplier = supplier
      @page = [page.to_i, 1].max
      @query = query.to_s.strip.slice(0, 120)
      @filter = FILTERS.include?(filter) ? filter : 'all'
      @status = status == 'deleted' ? 'deleted' : 'active'
    end

    def call
      relation = addresses_scope.joins(:country)
      relation = apply_search(relation) if @query.present?
      @filter_counts = calculate_filter_counts(relation)
      @total_count = @filter_counts.fetch(filter)
      load_addresses_page(apply_filter(relation))
      self
    end

    private

    def addresses_scope
      return @supplier.addresses.not_deleted if status == 'active'

      @supplier.addresses.with_deleted.where.not(deleted_at: nil)
    end

    def load_addresses_page(relation)
      ordering = status == 'deleted' ? { deleted_at: :desc, id: :desc } : { primary: :desc, purpose: :asc, id: :asc }
      rows = relation.includes(:country).order(ordering)
                     .offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
      @addresses = rows.first(PAGE_SIZE)
      @next_page = page + 1 if rows.size > PAGE_SIZE
    end

    def calculate_filter_counts(relation)
      counts = relation.group(:purpose, :primary).count
      result = FILTERS.index_with { 0 }
      counts.each do |(purpose, primary), count|
        result['all'] += count
        result[purpose] += count if result.key?(purpose)
        result['primary'] += count if primary
      end
      result['confirmed'] = relation.where.not(location_confirmed_at: nil).where.not(latitude: nil, longitude: nil).count
      result['approximate'] = relation.where(geocoding_status: 'success', location_confirmed_at: nil)
                                      .where.not(latitude: nil, longitude: nil).count
      result['pending'] = relation.where(geocoding_status: 'pending').count
      result['failed'] = relation.where(geocoding_status: 'failed').count
      result
    end

    def apply_filter(relation)
      return relation.where(primary: true) if filter == 'primary'
      return relation.where.not(location_confirmed_at: nil) if filter == 'confirmed'
      return relation.where(geocoding_status: 'success', location_confirmed_at: nil) if filter == 'approximate'
      return relation.where(geocoding_status: filter) if %w[pending failed].include?(filter)
      return relation if filter == 'all'

      relation.where(purpose: filter)
    end

    def apply_search(relation)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      relation.where(
        'addresses.street ILIKE :term OR addresses.exterior_number ILIKE :term OR ' \
        'addresses.interior_number ILIKE :term OR addresses.neighborhood ILIKE :term OR ' \
        'addresses.city ILIKE :term OR addresses.state ILIKE :term OR ' \
        'addresses.postal_code ILIKE :term OR addresses.reference_notes ILIKE :term OR ' \
        'countries.name ILIKE :term', term:
      )
    end
  end
end
