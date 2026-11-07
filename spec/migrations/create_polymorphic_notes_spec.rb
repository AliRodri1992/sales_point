# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Polymorphic notes database structure', type: :model do
  let(:legacy_tables) do
    %w[
      branches clients contacts goods_receipt_items goods_receipts purchase_approvals
      purchase_orders purchase_quotations purchase_request_items purchase_requests
      purchase_return_items purchase_returns supplier_credit_notes supplier_events
      supplier_invoices supplier_payments supplier_schedule_exceptions supplier_schedules suppliers
    ]
  end

  it 'stores general notes only in the polymorphic table' do
    legacy_tables.each do |table|
      expect(ActiveRecord::Base.connection.column_exists?(table, :notes)).to be(false), table
    end

    expect(Note.column_names).to include('notable_type', 'notable_id', 'body', 'kind', 'deleted_at')
  end

  it 'enforces unique active notes per owner and kind' do
    index = ActiveRecord::Base.connection.indexes(:notes).find { |entry| entry.name == 'idx_notes_notable_kind' }

    expect(index).to be_present
    expect(index).to be_unique
    expect(index.columns).to eq(%w[notable_type notable_id kind])
    expect(index.where).to include('deleted_at IS NULL')
  end

  it 'indexes tenant and chronology for note lookups' do
    indexes = ActiveRecord::Base.connection.indexes(:notes).map(&:name)

    expect(indexes).to include('idx_notes_org_created_at')
  end
end
