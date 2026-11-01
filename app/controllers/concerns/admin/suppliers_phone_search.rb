# frozen_string_literal: true

module Admin
  module SuppliersPhoneSearch
    BASE_SEARCH_SQL = 'suppliers.code ILIKE :term OR suppliers.name ILIKE :term'
    EMAIL_SEARCH_SQL = 'suppliers.email ILIKE :term'
    FISCAL_SEARCH_SQL = 'suppliers.rfc ILIKE :term'

    CONTACT_SEARCH_SQL = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM contacts
              WHERE contacts.contactable_type = 'Supplier'
                AND contacts.contactable_id = suppliers.id
                AND contacts.deleted_at IS NULL
                AND (contacts.name ILIKE :term OR contacts.email ILIKE :term
                     OR contacts.position ILIKE :term))
    SQL

    PRIMARY_CONTACT_SEARCH_SQL = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM contacts
              WHERE contacts.contactable_type = 'Supplier'
                AND contacts.contactable_id = suppliers.id
                AND contacts.deleted_at IS NULL
                AND contacts.primary = TRUE AND contacts.active = TRUE
                AND (contacts.name ILIKE :term OR contacts.email ILIKE :term
                     OR contacts.position ILIKE :term))
    SQL

    PHONE_SEARCH_SQL = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM contacts
              INNER JOIN phones ON phones.phoneable_type = 'Contact'
                AND phones.phoneable_id = contacts.id AND phones.deleted_at IS NULL
              WHERE contacts.contactable_type = 'Supplier'
                AND contacts.contactable_id = suppliers.id
                AND contacts.deleted_at IS NULL
                AND phones.number ILIKE :term)
    SQL

    private

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].to_s)}%"
      matches = scope.where(BASE_SEARCH_SQL, term:)
      matches = matches.or(scope.where(EMAIL_SEARCH_SQL, term:)) if supplier_general_visible?
      matches = matches.or(scope.where(FISCAL_SEARCH_SQL, term:)) if supplier_fiscal_visible?
      matches.or(contact_search_scope(scope, term))
    end

    def contact_search_scope(scope, term)
      if supplier_contacts_visible?
        return scope.where(CONTACT_SEARCH_SQL, term:).or(scope.where(PHONE_SEARCH_SQL, term:))
      end
      return scope.where(PRIMARY_CONTACT_SEARCH_SQL, term:) if supplier_general_visible?

      scope.none
    end
  end
end
