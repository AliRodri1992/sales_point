# frozen_string_literal: true

module Suppliers
  # A read-only, organization-scoped preview for the supplier dossier.
  class DossierProductsPage
    PAGE_SIZE = 4

    attr_reader :offers, :total_count, :total_pages, :page

    def initialize(supplier:, page: 1)
      @supplier = supplier
      @requested_page = page.to_i
    end

    def call
      relation = product_offers
      @total_count = relation.count
      @total_pages = [(total_count.to_f / PAGE_SIZE).ceil, 1].max
      @page = @requested_page.clamp(1, total_pages)
      @offers = load_page(relation)
      self
    end

    def from
      return 0 if total_count.zero?

      ((page - 1) * PAGE_SIZE) + 1
    end

    def to
      [page * PAGE_SIZE, total_count].min
    end

    def visible_pages
      first_page = (page - 2).clamp(1, [total_pages - 4, 1].max)
      (first_page..[first_page + 4, total_pages].min).to_a
    end

    private

    def product_offers
      @supplier.supplier_products.available.joins(:product)
               .merge(@supplier.organization.products.not_deleted)
    end

    def load_page(relation)
      relation.order('products.name ASC', 'supplier_products.id ASC')
              .includes(:currency, product: { image_attachment: :blob })
              .offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE).to_a
    end
  end
end
