# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Remaining finance and supplier model branch paths' do
  let(:organization) { create(:organization) }
  let(:supplier) { build(:supplier, organization:) }

  describe 'supplier validation combinations' do
    it 'accepts an individual RFC with a valid calendar date' do
      supplier.assign_attributes(person_type: 'individual', rfc: 'ABCD900101AAA')
      expect(supplier).to be_valid
    end

    it 'rejects a company RFC with an individual prefix' do
      supplier.assign_attributes(person_type: 'company', rfc: 'ABCD900101AAA')
      expect(supplier).not_to be_valid
    end

    it 'rejects an individual RFC with a company prefix' do
      supplier.assign_attributes(person_type: 'individual', rfc: 'ABC900101AAA')
      expect(supplier).not_to be_valid
    end

    it 'ignores invalid date calculation when RFC is missing' do
      supplier.rfc = nil
      supplier.valid?
      expect(supplier.errors.details[:rfc]).not_to include(hash_including(error: :invalid_date))
    end

    it 'rejects unsupported document formats' do
      supplier.documents.attach(
        io: StringIO.new('test'), filename: 'payload.exe', content_type: 'application/x-msdownload'
      )
      expect(supplier).not_to be_valid
      expect(supplier.errors[:documents]).to be_present
    end

    it 'rejects oversized documents without loading their contents' do
      attachment = supplier.documents.attach(io: StringIO.new('%PDF-1.4'), filename: 'large.pdf',
                                             content_type: 'application/pdf').first
      allow(attachment.blob).to receive(:byte_size).and_return(11.megabytes)
      expect(supplier).not_to be_valid
      expect(supplier.errors.details[:documents]).to include(hash_including(error: :file_too_large))
    end

    it 'accepts a supported PDF without exceeding the size limit' do
      supplier.documents.attach(
        io: StringIO.new('%PDF-1.4'), filename: 'small.pdf', content_type: 'application/pdf'
      )
      expect(supplier).to be_valid
    end

    it 'rejects a responsible user without a membership in the organization' do
      supplier.responsible_user = create(:user)
      expect(supplier).not_to be_valid
    end

    it 'accepts a responsible user in the same organization' do
      user = create(:user)
      create(:organization_membership, organization:, user:)
      supplier.responsible_user = user
      expect(supplier).to be_valid
    end

    it 'rejects an invalid telephone number' do
      supplier.phone = 'invalid'
      expect(supplier).not_to be_valid
    end

    it 'keeps absent optional telephone fields valid' do
      supplier.phone = nil
      expect(supplier).to be_valid
    end

    it 'normalizes duplicate and empty tags' do
      supplier.tags_text = ' stock , stock, , urgent, urgent '
      expect(supplier.tags).to eq(%w[stock urgent])
    end

    it 'returns normalized tags separated for editing' do
      supplier.tags = %w[first second]
      expect(supplier.tags_text).to eq('first, second')
    end
  end

  describe 'purchase order relationship validation combinations' do
    let(:branch) { create(:branch, organization:) }
    let(:saved_supplier) { create(:supplier, organization:) }
    let(:actor) { create(:user) }
    let(:order) do
      PurchaseOrder.new(
        organization:, branch:, supplier: saved_supplier,
        currency: saved_supplier.currency, requested_by: actor
      )
    end

    it 'accepts a purchase order without linked request or quotation' do
      expect(order).to be_valid
    end

    it 'rejects a branch from another organization' do
      order.branch = create(:branch, organization: create(:organization))
      expect(order).not_to be_valid
    end

    it 'rejects a supplier from another organization' do
      order.supplier = create(:supplier, organization: create(:organization))
      expect(order).not_to be_valid
    end

    it 'rejects a draft request even with matching branch and tenant' do
      order.purchase_request = PurchaseRequest.create!(
        organization:, branch:, requested_by: actor, status: :draft
      )
      expect(order).not_to be_valid
    end

    it 'rejects an approved request with a different branch' do
      order.purchase_request = PurchaseRequest.create!(
        organization:, branch: create(:branch, organization:, name: 'Request Branch'),
        requested_by: actor, status: :approved
      )
      expect(order).not_to be_valid
    end

    it 'accepts an approved purchase request from the same branch' do
      order.purchase_request = PurchaseRequest.create!(
        organization:, branch:, requested_by: actor, status: :approved
      )
      expect(order).to be_valid
    end

    it 'accepts an approved quotation without expiration date' do
      order.purchase_quotation = PurchaseQuotation.create!(
        organization:, supplier: saved_supplier, currency: saved_supplier.currency,
        status: :accepted
      )
      expect(order).to be_valid
    end

    it 'accepts a quotation expiring today' do
      order.purchase_quotation = PurchaseQuotation.create!(
        organization:, supplier: saved_supplier, currency: saved_supplier.currency,
        status: :accepted, valid_until: Date.current
      )
      expect(order).to be_valid
    end

    it 'rejects an expired quotation' do
      order.purchase_quotation = PurchaseQuotation.create!(
        organization:, supplier: saved_supplier, currency: saved_supplier.currency,
        status: :accepted, valid_until: Date.yesterday
      )
      expect(order).not_to be_valid
    end

    it 'rejects a quotation that was never accepted' do
      order.purchase_quotation = PurchaseQuotation.create!(
        organization:, supplier: saved_supplier, currency: saved_supplier.currency,
        status: :submitted
      )
      expect(order).not_to be_valid
    end

    it 'rejects a quotation from another supplier' do
      other = create(:supplier, organization:)
      order.purchase_quotation = PurchaseQuotation.create!(
        organization:, supplier: other, currency: saved_supplier.currency,
        status: :accepted
      )
      expect(order).not_to be_valid
    end

    it 'rejects a quotation associated with a different approved request' do
      request_record = PurchaseRequest.create!(
        organization:, branch:, requested_by: actor, status: :approved
      )
      order.purchase_quotation = PurchaseQuotation.create!(
        organization:, supplier: saved_supplier, currency: saved_supplier.currency,
        purchase_request: request_record, status: :accepted
      )
      expect(order).not_to be_valid
    end

    it 'accepts a quotation referencing the same approved request' do
      request_record = PurchaseRequest.create!(
        organization:, branch:, requested_by: actor, status: :approved
      )
      order.purchase_request = request_record
      order.purchase_quotation = PurchaseQuotation.create!(
        organization:, supplier: saved_supplier, currency: saved_supplier.currency,
        purchase_request: request_record, status: :accepted
      )
      expect(order).to be_valid
    end

    it 'rejects order items owned by another tenant' do
      order.purchase_order_items.build(
        product: create(:product, organization: create(:organization)),
        quantity: 2, units_per_package: 1, unit_price: 10
      )
      expect(order).not_to be_valid
    end

    it 'accepts own organization product entries' do
      order.purchase_order_items.build(
        product: create(:product, organization:),
        quantity: 2, units_per_package: 1, unit_price: 10
      )
      expect(order).to be_valid
    end
  end

  describe 'supplier schedule soft-delete recovery' do
    let(:saved_supplier) { create(:supplier, organization:) }
    let(:branch) { create(:branch, organization:) }
    let(:schedule) do
      SupplierSchedule.create!(supplier: saved_supplier, branch:, kind: 'visit',
                               weekday: 1, starts_at: '09:00')
    end

    it 'does not restore an active schedule' do
      expect(schedule.restore_safely).to be(false)
    end

    it 'restores a deleted schedule' do
      schedule.update!(deleted_at: Time.current)
      expect(schedule.restore_safely).to be(true)
      expect(schedule.reload.deleted_at).to be_nil
    end

    it 'rejects a restore if a replacement is invalid' do
      schedule.update!(deleted_at: Time.current)
      schedule.starts_at = nil
      expect(schedule.restore_safely).to be(false)
      expect(schedule.deleted_at).to be_present
    end

    it 'accepts a schedule with a blank end time' do
      schedule.ends_at = nil
      expect(schedule).to be_valid
    end

    it 'rejects identical start and end times' do
      schedule.ends_at = schedule.starts_at
      expect(schedule).not_to be_valid
    end
  end

  describe 'SAT response status rejection combinations' do
    let(:verifier) { AccountsPayable::SatStatusVerifier.allocate }

    it 'rejects malformed XML responses' do
      expect { verifier.send(:parse_response, '<unclosed') }
        .to raise_error(ArgumentError, 'Invalid SAT response')
    end

    it 'rejects a valid XML response missing its status field' do
      expect { verifier.send(:parse_response, '<root><CodigoEstatus>S</CodigoEstatus></root>') }
        .to raise_error(ArgumentError, 'Invalid SAT response')
    end

    it 'rejects an empty SAT response body' do
      expect { verifier.send(:parse_response, '') }
        .to raise_error(ArgumentError, 'Invalid SAT response')
    end

    it 'accepts a live SAT status response from an XML element' do
      xml = '<root><CodigoEstatus>S</CodigoEstatus><Estado>Vigente</Estado></root>'
      expect(verifier.send(:parse_response, xml)).to include(status: 'Vigente', code: 'S')
    end
  end

  describe 'purchase notification formatting branches' do
    it 'uses document code if the record responds to it' do
      message = PurchaseNotification.allocate
      allow(message).to receive_messages(record: Struct.new(:code).new('ORD-1'), params: { action: 'missing' })
      allow(message).to receive(:t).and_return('ORD-1')
      expect(message.message).to eq('ORD-1')
    end

    it 'uses the numeric identifier for a record without code' do
      message = PurchaseNotification.allocate
      allow(message).to receive_messages(record: Struct.new(:id).new(12), params: { action: 'missing' })
      expect(message).to receive(:t).with(anything, hash_including(name: '#12')).and_return('#12')
      expect(message.message).to eq('#12')
    end
  end
end
