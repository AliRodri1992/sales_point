# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierInvoice, type: :model do
  describe 'financial immutability' do
    let(:invoice) { described_class.new(status: :posted) }

    before do
      allow(invoice).to receive(:status_in_database).and_return('posted')
    end

    it 'rejects changes to a posted invoice' do
      allow(invoice).to receive(:changes_to_save).and_return('total' => [100, 200])
      invoice.send(:immutable_after_posting)

      expect(invoice.errors[:base]).to include('Posted or cancelled invoices cannot be edited')
    end

    it 'allows only the posted-to-cancelled transition' do
      invoice.status = :cancelled
      allow(invoice).to receive(:changes_to_save)
        .and_return('status' => %w[posted cancelled], 'cancelled_at' => [nil, Time.current])
      invoice.send(:immutable_after_posting)

      expect(invoice.errors[:base]).to be_empty
    end

    it 'rejects edits to cancelled invoices' do
      allow(invoice).to receive(:status_in_database).and_return('cancelled')
      allow(invoice).to receive(:changes_to_save).and_return('notes' => %w[old new])
      invoice.send(:immutable_after_posting)

      expect(invoice.errors[:base]).to include('Posted or cancelled invoices cannot be edited')
    end

    it 'blocks destruction of a posted invoice' do
      expect { invoice.send(:prevent_posted_destruction) }.to throw_symbol(:abort)
    end
  end
end
