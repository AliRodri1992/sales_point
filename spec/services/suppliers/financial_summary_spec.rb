# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::FinancialSummary do
  let(:supplier) { create(:supplier) }

  it 'displays a safe empty-balance label when a legacy supplier has no currency' do
    allow(supplier).to receive(:currency).and_return(nil)

    summary = described_class.new(supplier).call
    expect(summary.balance_labels { |amount| amount.to_s }).to eq(['0 —'])
    expect(summary.overdue_labels { |amount| amount.to_s }).to eq(['0 —'])
    expect(summary.pending_count).to eq(0)
  end

  it 'displays the supplier currency on an empty statement' do
    summary = described_class.new(supplier).call

    expect(summary.balance_labels { |amount| amount.to_s }).to eq(["0 #{supplier.currency.code}"])
    expect(summary.overdue_labels { |amount| amount.to_s }).to eq(["0 #{supplier.currency.code}"])
  end
end
