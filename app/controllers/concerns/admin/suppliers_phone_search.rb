# frozen_string_literal: true

module Admin
  module SuppliersPhoneSearch
    private

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      fields = ['suppliers.code ILIKE :term', 'suppliers.name ILIKE :term']
      fields << 'suppliers.email ILIKE :term' if supplier_general_visible?
      if supplier_contacts_visible? || supplier_general_visible?
        scope_filter = supplier_contacts_visible? ? '' : 'AND contacts.primary = TRUE AND contacts.active = TRUE'
        fields << <<~SQL.squish
          EXISTS (SELECT 1 FROM contacts
                  WHERE contacts.contactable_type = 'Supplier'
                    AND contacts.contactable_id = suppliers.id
                    AND contacts.deleted_at IS NULL #{scope_filter}
                    AND (contacts.name ILIKE :term OR contacts.email ILIKE :term
                         OR contacts.position ILIKE :term))
        SQL
      end
      if supplier_contacts_visible?
        fields << <<~SQL.squish
          EXISTS (SELECT 1 FROM contacts
                  INNER JOIN phones ON phones.phoneable_type = 'Contact'
                    AND phones.phoneable_id = contacts.id AND phones.deleted_at IS NULL
                  WHERE contacts.contactable_type = 'Supplier' AND contacts.contactable_id = suppliers.id
                    AND contacts.deleted_at IS NULL AND phones.number ILIKE :term)
        SQL
      end
      fields << 'suppliers.rfc ILIKE :term' if supplier_fiscal_visible?

      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].to_s)}%"
      scope.where(fields.join(' OR '), term:)
    end
  end
end
