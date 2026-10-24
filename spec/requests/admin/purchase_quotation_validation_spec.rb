# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase quotation validation and protected transitions', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }
  let(:product) { create(:product, organization:) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def quotation(attributes = {})
    PurchaseQuotation.create!({
      organization:, supplier:, currency: supplier.currency, status: :draft
    }.merge(attributes)).tap do |record|
      record.purchase_quotation_items.create!(
        product:, quantity: 1, units_per_package: 1, unit_price: 10
      )
    end
  end

  it 'prepares three empty item rows when creating a quotation without a request' do
    get new_admin_purchase_quotation_path

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('input[name*="[quantity]"]').length).to eq(3)
  end

  it 'rejects editing a quotation after submission' do
    record = quotation(status: :submitted)

    get edit_admin_purchase_quotation_path(record)

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects changing an accepted quotation through draft-only updates' do
    record = quotation(status: :accepted)

    patch admin_purchase_quotation_path(record), params: {
      purchase_quotation: { notes: 'Unauthorized change' }
    }

    expect(response).to have_http_status(:not_found)
    expect(record.reload.notes).to be_nil
  end

  it 'keeps invalid newly submitted quotations on the form' do
    post admin_purchase_quotations_path, params: {
      purchase_quotation: { supplier_id: supplier.id, currency_id: supplier.currency.id,
                            purchase_quotation_items_attributes: {
                              '0' => { product_id: product.id, quantity: -1, units_per_package: 1, unit_price: 5 }
                            } }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.purchase_quotations.count).to eq(0)
  end

  it 'rejects invalid edits to a draft quotation while keeping the original data' do
    record = quotation

    patch admin_purchase_quotation_path(record), params: {
      purchase_quotation: { supplier_id: create(:supplier, organization: create(:organization)).id }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.supplier).to eq(supplier)
  end

  it 'refuses to accept an expired submitted quotation' do
    record = quotation(status: :submitted, valid_until: Date.yesterday)

    post accept_admin_purchase_quotation_path(record)

    expect(response).to redirect_to(admin_purchase_quotation_path(record))
    expect(record.reload).to be_submitted
  end

  it 'rejects submitting a quotation twice without corrupting its state' do
    record = quotation(status: :submitted)

    post submit_admin_purchase_quotation_path(record)

    expect(response).to redirect_to(admin_purchase_quotation_path(record))
    expect(record.reload).to be_submitted
  end

  it 'does not expose quotations of another organization through edit routes' do
    foreign = create(:organization)
    record = PurchaseQuotation.create!(
      organization: foreign, supplier: create(:supplier, organization: foreign),
      currency: supplier.currency, status: :draft
    )

    get edit_admin_purchase_quotation_path(record)

    expect(response).to have_http_status(:not_found)
  end
end
