# frozen_string_literal: true

module Admin
  module SuppliersPhoneSearch
    private

  def apply_search_filter(scope)
    return scope if params[:search].blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].to_s)}%"
    scope.where(<<~SQL.squish, term:, can_general: supplier_general_visible?, can_fiscal: supplier_fiscal_visible?)
      suppliers.code ILIKE :term OR suppliers.name ILIKE :term
      OR (:can_general AND (suppliers.email ILIKE :term OR
        EXISTS (SELECT 1 FROM phones WHERE phones.phoneable_type = 'Supplier'
                AND phones.phoneable_id = suppliers.id AND phones.deleted_at IS NULL
                AND phones.number ILIKE :term)))
      OR (:can_fiscal AND suppliers.rfc ILIKE :term)
    SQL
  end

  end
end
