# frozen_string_literal: true

module Admin
  module SuppliersPhoneSearch
    private

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      fields = ['suppliers.code ILIKE :term', 'suppliers.name ILIKE :term']
      if supplier_general_visible?
        fields << 'suppliers.email ILIKE :term'
        fields << <<~SQL.squish
          EXISTS (SELECT 1 FROM phones WHERE phones.phoneable_type = 'Supplier'
                  AND phones.phoneable_id = suppliers.id AND phones.deleted_at IS NULL
                  AND phones.number ILIKE :term)
        SQL
      end
      fields << 'suppliers.rfc ILIKE :term' if supplier_fiscal_visible?

      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].to_s)}%"
      scope.where(fields.join(' OR '), term:)
    end
  end
end
