# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Commercial::Lifecycle do
  let(:organization) { create(:organization) }
  let(:actor) { create(:user) }
  let(:product) { create(:product, organization:, cost: 4) }
  let(:list) { PriceList.create!(organization:, name: 'Retail', currency: 'MXN') }
  let(:promotion) { Promotion.create!(organization:, name: 'Summer', currency: 'MXN') }

  before { create(:currency, code: 'MXN') }

  def transition(record, action)
    described_class.new(record:, actor:).call(action)
  end

  it 'uses the organization currency by default and preserves an explicit alternative' do
    dollar = create(:currency, code: 'USD')
    create(:organization_setting, organization:, base_currency: dollar)
    expect(Promotion.create!(organization:, name: 'Local').currency).to eq('USD')
    expect(list.currency).to eq('MXN')
  end

  it 'allocates separate codes per organization and catalog, preserving historical codes' do
    old = PriceList.create!(organization:, name: 'Legacy', currency: 'MXN', code: 'CUSTOM')
    PriceList.create!(organization:, name: 'Imported', currency: 'MXN', code: 'LP-000004')
    expect(list.code).to eq('LP-000005')
    expect(promotion.code).to eq('PRO-000001')
    expect(PriceList.create!(organization: create(:organization), name: 'Retail', currency: 'MXN').code)
      .to eq('LP-000001')
    expect(old.update(code: 'TAMPERED')).to be(false)
    expect(old.reload.code).to eq('CUSTOM')
  end

  it 'allocates distinct codes to simultaneous creates even after both records were validated', :concurrent_db do
    org_id = organization.id
    ready = Queue.new
    start = Queue.new
    workers = Array.new(2) do
      Thread.new do
        ApplicationRecord.connection_pool.with_connection do
          record = Promotion.new(organization_id: org_id, name: 'Offer', currency: 'MXN')
          begin
            record.valid?
          ensure
            ready << true
          end
          start.pop
          record.save!
          record.code
        end
      end
    end
    workers.size.times { ready.pop }
    workers.size.times { start << true }
    expect(workers.map(&:value)).to contain_exactly('PRO-000001', 'PRO-000002')
  end

  it 'requires rows or benefits to activate, and allows only the documented transitions' do
    [list, promotion].each do |record|
      expect { transition(record, 'activate') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(record.reload.effective_status).to eq('draft')
    end
    list.price_list_items.create!(product:, price: 10)
    expect(transition(list, 'activate').effective_status).to eq('active')
    expect(transition(list, 'pause').effective_status).to eq('paused')
    expect(transition(list, 'resume').effective_status).to eq('active')
    expect(transition(list, 'archive').effective_status).to eq('archived')
    %w[activate pause resume archive].each do |action|
      expect { transition(list, action) }.to raise_error(ActiveRecord::RecordInvalid)
    end
    events = FinancialAuditEvent.where(organization:, subject_type: 'PriceList', subject_id: list.id)
    expected_events = %w[price_list.activate price_list.pause price_list.resume price_list.archive]
    expect(events.order(:id).pluck(:event)).to eq(expected_events)
    expect(events.last.actor).to eq(actor)
  end

  it 'requires a live row with a usable period when activating a price list' do
    list.price_list_items.create!(product:, price: 5).retire!
    list.price_list_items.create!(product:, price: 6, ends_at: 1.day.ago)
    expect { transition(list, 'activate') }.to raise_error(ActiveRecord::RecordInvalid)
    list.update!(starts_at: 1.day.from_now, ends_at: 3.days.from_now)
    list.price_list_items.create!(product:, price: 8, starts_at: 2.days.from_now)
    expect(transition(list, 'activate').effective_status).to eq('scheduled')
  end

  it 'requires below-cost authority to duplicate, activate and resume a list containing a discounted presentation' do
    pack = product.product_presentations.create!(name: 'Pack', units: 10)
    list.price_list_items.create!(product:, product_presentation: pack, price: 30)
    expect { transition(list, 'duplicate') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(PriceList.where(organization:).count).to eq(1)
    expect { transition(list, 'activate') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(list.reload).to be_draft
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: admin)
    authorized = described_class.new(record: list, actor: admin)
    expect(authorized.call('duplicate')).to be_draft
    expect(authorized.call('activate')).to be_active
    expect(transition(list, 'pause')).to be_paused
    expect { transition(list, 'resume') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(authorized.call('resume')).to be_active
  end

  it 'permits activation with a historical below-cost price that is no longer available' do
    boundary = 1.day.ago
    list.price_list_items.create!(product:, price: 1, ends_at: boundary)
    list.price_list_items.create!(product:, price: 10, starts_at: boundary)
    expect(transition(list, 'activate')).to be_active
  end

  it 'honors exact time bounds, persisted-state precedence and the global quota' do
    starts = Time.current.change(usec: 0) + 1.hour
    promotion.update!(starts_at: starts, ends_at: starts + 1.hour, usage_limit: 1, customer_limit: 1)
    promotion.promotion_benefits.create!(kind: 'percentage', value: 5)
    transition(promotion, 'activate')
    expect(promotion.effective_status(at: starts - 1.second)).to eq('scheduled')
    expect(promotion.effective_status(at: starts)).to eq('active')
    promotion.promotion_redemptions.create!(organization:, product:, quantity: 1, discount: 1,
                                            idempotency_key: 'USED')
    expect(promotion.effective_status(at: starts)).to eq('exhausted')
    expect(promotion.effective_status(at: starts + 1.hour)).to eq('expired')
    promotion.update!(status: 'paused')
    expect(promotion.effective_status(at: starts + 1.hour)).to eq('paused')
    expect { transition(promotion, 'resume') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'duplicates campaign rules as a new draft without reusing redemption or audit history' do
    promotion.promotion_conditions.create!(kind: 'excluded_product', product:)
    promotion.promotion_benefits.create!(kind: 'fixed_amount', value: 5)
    transition(promotion, 'activate')
    promotion.promotion_redemptions.create!(organization:, product:, quantity: 1, discount: 5,
                                            idempotency_key: 'ORDER')
    transition(promotion, 'archive')
    copy = transition(promotion, 'duplicate')
    expect(copy).to be_draft
    expect(copy.code).to eq('PRO-000002')
    expect(copy.promotion_conditions.sole.product).to eq(product)
    expect(copy.promotion_benefits.sole.value).to eq(5)
    expect(copy.promotion_redemptions).to be_empty
    expect(FinancialAuditEvent.where(subject_type: 'Promotion', subject_id: copy.id).sole.details['source_id'])
      .to eq(promotion.id)
  end

  it 'preserves price history on retirement and duplicates only live price rows' do
    item = list.price_list_items.create!(product:, price: 8, minimum_quantity: 5)
    event = item.price_change_events.create!(organization:, product:, actor:, currency: 'MXN',
                                             new_price: 8, reason: 'Opening price')
    item.retire!
    list.price_list_items.create!(product:, price: 9, minimum_quantity: 5)
    expect(PriceListItem.with_deleted.find(item.id).price_change_events.sole).to eq(event)
    copy = transition(list, 'duplicate')
    expect(copy.price_list_items.sole.price).to eq(9)
    expect(copy.price_list_items.sole.minimum_quantity).to eq(5)
    expect(copy.price_list_items.sole.price_change_events).to be_empty
  end

  it 'rejects inactive products and options on new rows but permits unchanged historical references' do
    variant = product.product_variants.create!(organization:, name: 'Small')
    original = list.price_list_items.create!(product:, product_variant: variant, price: 10)
    variant.update!(status: 'inactive')
    product.update!(status: 'inactive')
    expect(original.reload.update(price: 9)).to be(true)
    row = list.price_list_items.build(product:, product_variant: variant, price: 10, minimum_quantity: 2)
    expect(row).not_to be_valid
    expect(row.errors[:product]).to be_present
    expect(row.errors[:product_variant]).to be_present
  end

  it 'validates campaign caps, combination rules, and tenant ownership of target lists' do
    foreign = PriceList.create!(organization: create(:organization), name: 'Other', currency: 'MXN', status: 'active')
    promotion.assign_attributes(price_list: foreign, maximum_discount: -1, combination_mode: 'stackable')
    expect(promotion).not_to be_valid
    expect(promotion.errors.attribute_names).to include(:price_list, :maximum_discount, :combination_mode)
    list.update!(status: 'active')
    expect(promotion.update(price_list: list, maximum_discount: '1.12345678', combination_mode: 'exclusive'))
      .to be(true)
    expect(promotion.reload.maximum_discount).to eq(BigDecimal('1.12345678'))
  end

  it 'keeps a persisted price row tied to its product and tier' do
    item = list.price_list_items.create!(product:, price: 10, minimum_quantity: 2)
    expect(item.update(minimum_quantity: 4)).to be(false)
    expect(item.errors[:minimum_quantity]).to be_present
    expect(item.reload.minimum_quantity).to eq(2)
    expect(list.price_list_items.create!(product:, price: 9, minimum_quantity: 4)).to be_persisted
  end
end
