# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase quotation lifecycle authorization and validation', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def quotation(status: 'draft', valid_until: Date.tomorrow)
    PurchaseQuotation.create!(
      organization:, supplier:, currency: supplier.currency, status:, valid_until:
    )
  end

  it 'refuses editing an already accepted quotation' do
    record = quotation(status: 'accepted')

    get edit_admin_purchase_quotation_path(record)
    expect(response).to have_http_status(:not_found)
  end

  it 'refuses updating an already submitted quotation' do
    record = quotation(status: 'submitted')

    patch admin_purchase_quotation_path(record),
          params: { purchase_quotation: { notes: 'Unauthorized changes' } }

    expect(response).to have_http_status(:not_found)
    expect(record.reload.notes).not_to eq('Unauthorized changes')
  end

  it 'rejects missing supplier and currency information on creation' do
    post admin_purchase_quotations_path, params: { purchase_quotation: { notes: 'Incomplete' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.purchase_quotations).to be_empty
  end

  it 'prevents submitting the same quotation twice' do
    record = quotation
    post submit_admin_purchase_quotation_path(record)
    expect(response).to redirect_to(admin_purchase_quotation_path(record))
    expect(record.reload).to be_submitted

    post submit_admin_purchase_quotation_path(record)
    expect(response).to redirect_to(admin_purchase_quotation_path(record))
    expect(record.reload).to be_submitted
  end

  it 'refuses accepting an expired quotation while preserving its submitted status' do
    record = quotation(status: 'submitted', valid_until: Date.yesterday)

    post accept_admin_purchase_quotation_path(record)

    expect(response).to redirect_to(admin_purchase_quotation_path(record))
    expect(record.reload).to be_submitted
  end
end
