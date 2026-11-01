require 'rails_helper'

RSpec.describe SupplierNotification, type: :model do
  let(:user) { create(:user) }
  let(:supplier) { create(:supplier, name: 'Proveedor Demo') }

  it 'builds a notification for the correct recipient and record' do
    notification = described_class.with(action: 'created', record: supplier, user:)

    expect(notification.record).to eq(supplier)
    expect(notification.params[:user]).to eq(user)
    expect(notification.params[:action]).to eq('created')
  end

  it 'builds the localized message' do
    notification = described_class.with(action: 'updated', record: supplier, user:)

    expect(notification.message).to include('Proveedor Demo')
  end
end
