# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequests::Filters do
  subject(:filters) { described_class.new(params, create(:user)) }

  let(:params) { { page: '1', per_page: '10' } }

  describe '#call' do
    it 'returns requests matching a valid status' do
      matching = create(:demo_request, name: 'Pending prospect', status: :pending)
      create(
        :demo_request,
        name: 'Contacted prospect',
        status: :contacted,
        contacted_at: Time.current,
        contact_channel: 'call',
        contact_outcome: 'interested'
      )

      result = described_class.new(params.merge(status: 'pending'), create(:user)).call

      expect(result).to include(matching)
      expect(result.map(&:name)).not_to include('Contacted prospect')
    end

    it 'filters by an overdue follow-up' do
      overdue = create(
        :demo_request,
        status: :contacted,
        contacted_at: 2.days.ago,
        contact_channel: 'call',
        contact_outcome: 'interested',
        next_action: 'Call prospect',
        next_follow_up_at: 1.hour.ago
      )
      create(
        :demo_request,
        status: :contacted,
        contacted_at: Time.current,
        contact_channel: 'call',
        contact_outcome: 'interested',
        next_follow_up_at: 1.day.from_now
      )

      result = described_class.new(params.merge(follow_up: 'overdue'), create(:user)).call

      expect(result).to include(overdue)
      expect(result.count).to eq(1)
    end

    it 'filters by an upcoming follow-up' do
      upcoming = create(
        :demo_request,
        status: :contacted,
        contacted_at: Time.current,
        contact_channel: 'call',
        contact_outcome: 'interested',
        next_follow_up_at: 1.day.from_now
      )

      result = described_class.new(params.merge(follow_up: 'upcoming'), create(:user)).call

      expect(result).to include(upcoming)
      expect(result.count).to eq(1)
    end

    it 'filters by a valid contact outcome and ignores an invalid one' do
      interested = create(
        :demo_request,
        status: :contacted,
        contacted_at: Time.current,
        contact_channel: 'call',
        contact_outcome: 'interested'
      )
      create(
        :demo_request,
        status: :contacted,
        contacted_at: Time.current,
        contact_channel: 'call',
        contact_outcome: 'no_answer'
      )

      result = described_class.new(params.merge(contact_outcome: 'interested'), create(:user)).call

      expect(result).to include(interested)
      expect(result.count).to eq(1)

      invalid_result = described_class.new(params.merge(contact_outcome: 'invalid'), create(:user)).call
      expect(invalid_result.count).to eq(2)
    end

    it 'filters by a valid demo outcome and ignores an invalid one' do
      matching = create(:demo_request, demo_outcome: 'very_interested')
      create(:demo_request, demo_outcome: 'no_show')

      result = described_class.new(params.merge(demo_outcome: 'very_interested'), create(:user)).call

      expect(result).to include(matching)
      expect(result.count).to eq(1)

      invalid_result = described_class.new(params.merge(demo_outcome: 'invalid'), create(:user)).call
      expect(invalid_result.count).to eq(2)
    end

    it 'searches across request contact fields' do
      matching = create(:demo_request, name: 'Searchable prospect', company: 'Northwind')
      create(:demo_request, name: 'Different prospect', company: 'Contoso')

      result = described_class.new(params.merge(search: 'Northwind'), create(:user)).call

      expect(result).to include(matching)
      expect(result.count).to eq(1)
    end
  end

  describe '#metrics' do
    it 'returns zero conversion rate for an empty dataset' do
      expect(filters.metrics).to include(
        total: 0,
        pending: 0,
        overdue_follow_ups: 0,
        conversion_rate: 0
      )
    end

    it 'calculates totals and conversion rate' do
      create_list(:demo_request, 2, status: :pending)
      create(:demo_request, status: :converted)

      expect(filters.metrics).to include(
        total: 3,
        pending: 2,
        converted: 1,
        conversion_rate: 33.3
      )
    end
  end

  describe '#pagination_info' do
    before { create_list(:demo_request, 12) }

    it 'uses supported page sizes and clamps the page to the available range' do
      result = described_class.new(params.merge(per_page: '5', page: '99'), create(:user)).pagination_info

      expect(result).to include(per_page: 5, total_count: 12, total_pages: 3, current_page: 3)
    end

    it 'falls back to ten items for unsupported page sizes' do
      result = described_class.new(params.merge(per_page: '7'), create(:user)).pagination_info

      expect(result[:per_page]).to eq(10)
    end
  end
end
