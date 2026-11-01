# frozen_string_literal: true

module SupplierContactSearch
  private

  def contact_scope
    if params[:status] == 'deleted'
        @supplier.contacts.with_deleted.where.not(deleted_at: nil)
    else
        @supplier.contacts.not_deleted
  end
  end

  def filtered_contact_scope
    scope = contact_scope
    query = params[:q].to_s.strip.first(100)
    return scope if query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.where(
        <<~SQL.squish, q: term
          contacts.name ILIKE :q OR contacts.position ILIKE :q OR contacts.email ILIKE :q
          OR EXISTS (SELECT 1 FROM phones
                     WHERE phones.phoneable_type = 'Contact'
                       AND phones.phoneable_id = contacts.id
                       AND phones.deleted_at IS NULL
                       AND phones.number ILIKE :q)
        SQL
    )
  end
end
