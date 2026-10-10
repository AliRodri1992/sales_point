# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::DemoRequestsHelper, type: :helper do
  let(:activity) { instance_double(DemoRequestActivity, action:, details:) }
  let(:action) { 'created' }
  let(:details) { {} }

  before do
    allow(helper).to receive(:t) do |key, **options|
      [key, *options.values].join(' ')
    end
    allow(helper).to receive(:l) { |date, format:| "#{date.to_date.iso8601}:#{format}" }
  end

  describe '#demo_request_activity_description' do
    context 'when details are a non-structured string' do
      let(:details) { 'A manually recorded activity' }

      it 'returns the original details' do
        expect(helper.demo_request_activity_description(activity)).to eq(details)
      end
    end

    context 'when details are blank' do
      let(:details) { '' }

      it 'falls back to the activity translation' do
        expect(helper.demo_request_activity_description(activity)).to include(
          'admin.demo_requests.activity.created'
        )
      end
    end

    it 'translates status changes from the old status to the new status' do
      allow(activity).to receive(:action).and_return('status_changed')
      allow(activity).to receive(:details).and_return({ from: 'pending', to: 'scheduled' })

      result = helper.demo_request_activity_description(activity)

      expect(result).to include('admin.demo_requests.activity.status_changed')
      expect(result).to include('admin.demo_requests.statuses.pending')
      expect(result).to include('admin.demo_requests.statuses.scheduled')
    end

    it 'describes unassigned requests' do
      allow(activity).to receive(:action).and_return('assigned')
      allow(activity).to receive(:details).and_return({ assigned_to: 'unassigned' })

      expect(helper.demo_request_activity_description(activity)).to include(
        'admin.demo_requests.activity.unassigned'
      )
    end

    it 'describes assignments to a named user' do
      allow(activity).to receive(:action).and_return('assigned')
      allow(activity).to receive(:details).and_return({ assigned_to: 'Ada' })

      expect(helper.demo_request_activity_description(activity)).to include(
        'admin.demo_requests.activity.assigned_to Ada'
      )
    end

    it 'translates contact channel and outcome details' do
      allow(activity).to receive(:action).and_return('contact_registered')
      allow(activity).to receive(:details).and_return(
        { channel: 'whatsapp', outcome: 'interested' }
      )

      result = helper.demo_request_activity_description(activity)

      expect(result).to include('admin.demo_requests.contact_channels.whatsapp')
      expect(result).to include('admin.demo_requests.contact_outcomes.interested')
    end

    it 'formats follow-up dates and supplies a dash for a missing action' do
      allow(activity).to receive(:action).and_return('follow_up_scheduled')
      allow(activity).to receive(:details).and_return({ date: '2026-10-12', action: '' })

      result = helper.demo_request_activity_description(activity)

      expect(result).to include('admin.demo_requests.activity.follow_up_scheduled')
      expect(result).to include('2026-10-12:short')
      expect(result).to include('—')
    end

    it 'describes the demo outcome' do
      allow(activity).to receive(:action).and_return('demo_outcome_recorded')
      allow(activity).to receive(:details).and_return({ outcome: 'very_interested' })

      expect(helper.demo_request_activity_description(activity)).to include(
        'admin.demo_requests.demo_outcomes.very_interested'
      )
    end

    it 'parses serialized legacy hash details' do
      allow(activity).to receive(:action).and_return('contact_registered')
      allow(activity).to receive(:details).and_return(
        '{:channel=>"whatsapp", :outcome=>"interested"}'
      )

      result = helper.demo_request_activity_description(activity)

      expect(result).to include('admin.demo_requests.contact_channels.whatsapp')
      expect(result).to include('admin.demo_requests.contact_outcomes.interested')
    end

    it 'returns a dash for a blank translated status value' do
      expect(helper.send(:translated_status, nil)).to eq('—')
    end

    it 'returns a dash for a blank translated value' do
      expect(helper.send(:translated_value, 'contact_outcomes', '')).to eq('—')
    end

    it 'returns the original value when an activity date cannot be parsed' do
      expect(helper.send(:translated_activity_date, 'not-a-date')).to eq('not-a-date')
    end
  end
end
