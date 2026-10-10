# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequests::Validations do
  describe '.validate_follow_up_scheduling' do
    it 'does not add errors when both follow-up fields are blank' do
      request = build(:demo_request)

      described_class.validate_follow_up_scheduling(request)

      expect(request.errors).to be_empty
    end

    it 'requires a follow-up date when a next action is supplied' do
      request = build(:demo_request, next_action: 'Call customer', next_follow_up_at: nil)

      described_class.validate_follow_up_scheduling(request)

      expect(request.errors.of_kind?(:next_follow_up_at, :blank)).to be(true)
    end

    it 'requires a next action when a follow-up date is supplied' do
      request = build(:demo_request, next_action: nil, next_follow_up_at: 1.day.from_now)

      described_class.validate_follow_up_scheduling(request)

      expect(request.errors.of_kind?(:next_action, :blank)).to be(true)
    end
  end

  describe '.validate_contact_required' do
    it 'does nothing before the request has been contacted' do
      request = build(:demo_request, contacted_at: nil, contact_channel: nil, contact_outcome: nil)

      described_class.validate_contact_required(request)

      expect(request.errors).to be_empty
    end

    it 'requires both a contact channel and outcome after contact' do
      request = build(
        :demo_request,
        contacted_at: Time.current,
        contact_channel: nil,
        contact_outcome: nil
      )

      described_class.validate_contact_required(request)

      expect(request.errors.of_kind?(:contact_channel, :blank)).to be(true)
      expect(request.errors.of_kind?(:contact_outcome, :blank)).to be(true)
    end

    it 'does not add errors when contact details are complete' do
      request = build(
        :demo_request,
        contacted_at: Time.current,
        contact_channel: 'call',
        contact_outcome: 'interested'
      )

      described_class.validate_contact_required(request)

      expect(request.errors).to be_empty
    end
  end

  describe '.validate_conversion_follow_up' do
    it 'requires a conversion timestamp for converted requests' do
      request = build(:demo_request, status: :converted, converted_at: nil)

      described_class.validate_conversion_follow_up(request)

      expect(request.errors.of_kind?(:converted_at, :blank)).to be(true)
    end

    it 'does not add an error when a converted request has a timestamp' do
      request = build(:demo_request, status: :converted, converted_at: Time.current)

      described_class.validate_conversion_follow_up(request)

      expect(request.errors).to be_empty
    end

    it 'does not require a conversion timestamp for other statuses' do
      request = build(:demo_request, status: :pending, converted_at: nil)

      described_class.validate_conversion_follow_up(request)

      expect(request.errors).to be_empty
    end
  end

  describe '.validate_commercial_follow_up' do
    it 'runs the three commercial validation groups' do
      request = build(
        :demo_request,
        next_action: 'Call customer',
        next_follow_up_at: nil,
        contacted_at: Time.current,
        contact_channel: nil,
        contact_outcome: nil,
        status: :converted,
        converted_at: nil
      )

      described_class.validate_commercial_follow_up(request)

      expect(request.errors.of_kind?(:next_follow_up_at, :blank)).to be(true)
      expect(request.errors.of_kind?(:contact_channel, :blank)).to be(true)
      expect(request.errors.of_kind?(:contact_outcome, :blank)).to be(true)
      expect(request.errors.of_kind?(:converted_at, :blank)).to be(true)
    end
  end
end
