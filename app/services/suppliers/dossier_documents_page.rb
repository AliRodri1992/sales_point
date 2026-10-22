# frozen_string_literal: true

module Suppliers
  class DossierDocumentsPage
    PER_PAGE = 8
    attr_reader :documents, :total_count, :page, :total_pages

    def initialize(supplier:, page: nil, filters: {})
      @supplier = supplier
      @requested_page = page
      @query = filters[:query].to_s.strip.first(120)
      @category = filters[:category]
      @status = filters[:status]
      @days = filters[:days]
    end

    def call
      scope = filtered_scope
      @total_count = scope.count
      @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
      @page = @requested_page.to_i.clamp(1, @total_pages)
      @documents = scope.includes(attachment: :blob)
                        .order(created_at: :desc, id: :desc)
                        .limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      self
    end

    private

    def filtered_scope
      scope = @supplier.supplier_documents.visible.joins(attachment: :blob)
      scope = search_scope(scope) if @query.present?
      scope = scope.where(category: @category) if SupplierDocument::CATEGORIES.include?(@category)
      scope = scope.where(status: @status) if SupplierDocument::STATUSES.include?(@status)
      scope = scope.where(active_storage_attachments: { created_at: @days.to_i.days.ago.. }) if @days.in?(%w[30 365])
      scope
    end

    def search_scope(scope)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope.where(
        'active_storage_blobs.filename ILIKE :term OR supplier_documents.description ILIKE :term',
        term:
      )
    end
  end
end
