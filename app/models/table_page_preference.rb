# frozen_string_literal: true

class TablePagePreference < ApplicationRecord
  OPTIONS = [5, 10, 15, 25, 50].freeze
  DEFAULT = 10
  TABLE_KEYS = %w[
    suppliers categories languages products clients branches users demo_requests
    account_payables supplier_invoices supplier_payments supplier_credit_notes
    purchase_orders purchase_requests purchase_quotations
  ].freeze

  belongs_to :user
  belongs_to :organization

  validates :table_key, presence: true, inclusion: { in: TABLE_KEYS },
                        uniqueness: { scope: %i[user_id organization_id],
                                      conditions: -> { where(deleted_at: nil) } }
  validates :per_page, inclusion: { in: OPTIONS }
end
