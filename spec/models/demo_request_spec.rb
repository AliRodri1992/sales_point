# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequest, type: :model do
  subject(:demo_request) { build(:demo_request) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:company) }
    it { is_expected.to validate_presence_of(:phone) }
    it { is_expected.to validate_presence_of(:business_type) }
    it { is_expected.to validate_presence_of(:branches) }
    it { is_expected.to validate_acceptance_of(:terms_accepted) }

    it 'rejects invalid email' do
      demo_request.email = 'invalid'
      expect(demo_request).to be_invalid
    end

    it 'normalizes email' do
      demo_request.email = '  USER@EXAMPLE.COM  '
      demo_request.valid?
      expect(demo_request.email).to eq('user@example.com')
    end

    it 'normalizes name and company whitespace' do
      demo_request.name = '  Test   User  '
      demo_request.company = '  Test   Company  '
      demo_request.valid?
      expect(demo_request.name).to eq('Test User')
      expect(demo_request.company).to eq('Test Company')
    end

    it 'rejects short name and company' do
      demo_request.name = 'A'
      demo_request.company = 'A'
      expect(demo_request).to be_invalid
    end

    it 'rejects blank-only name and company' do
      demo_request.name = '   '
      demo_request.company = '   '
      expect(demo_request).to be_invalid
    end

    it 'accepts E.164 phone numbers' do
      demo_request.phone = '+525512345678'
      expect(demo_request).to be_valid
    end

    it 'accepts valid international phone numbers' do
      {
        '+14155552671' => 'US',
        '+442071838750' => 'GB',
        '+82212345678' => 'KR'
      }.each do |phone, country|
        demo_request.phone = phone
        expect(demo_request).to be_valid
        expect(Phonelib.parse(phone).country).to eq(country)
      end
    end

    it 'normalizes valid phone numbers to E.164' do
      demo_request.phone = '+52 55 1234 5678'
      expect { demo_request.valid? }.to change(demo_request, :phone).to('+525512345678')
    end

    it 'rejects phone values that are not E.164' do
      %w[5512345678 123456789 +025512345678 +525512345678901234].each do |phone|
        demo_request.phone = phone
        expect(demo_request).to be_invalid
      end
    end

    it 'rejects phone extensions' do
      demo_request.phone = '+525512345678;123'
      expect(demo_request).to be_invalid
    end

    it 'rejects blank phone numbers' do
      demo_request.phone = '   '
      expect(demo_request).to be_invalid
    end

    it 'rejects phone numbers with invalid country codes' do
      demo_request.phone = '+999123456789'
      expect(demo_request).to be_invalid
    end

    it 'rejects invalid business type' do
      demo_request.business_type = 'invalid'
      expect(demo_request).to be_invalid
    end

    it 'rejects invalid branch counts' do
      [0, DemoRequest::MAX_BRANCHES + 1, 'invalid'].each do |branches|
        demo_request.branches = branches
        expect(demo_request).to be_invalid
      end
    end

    it 'allows blank message' do
      demo_request.message = nil
      expect(demo_request).to be_valid
    end

    it 'rejects oversized message' do
      demo_request.message = 'A' * 2_001
      expect(demo_request).to be_invalid
    end

    it 'rejects unaccepted terms' do
      demo_request.terms_accepted = false
      expect(demo_request).to be_invalid
    end

    it 'records the terms acceptance timestamp' do
      expect { demo_request.valid? }.to change(demo_request, :terms_accepted_at).from(nil)
    end
  end

  describe 'status' do
    it 'defines statuses' do
      expect(described_class.statuses).to eq('pending' => 'pending', 'contacted' => 'contacted',
                                             'completed' => 'completed')
    end

    it 'defaults to pending' do
      expect(described_class.new.status).to eq('pending')
    end
  end

  describe 'callbacks' do
    it 'delivers notification' do
      notification = instance_double(DemoRequestNotification)
      allow(DemoRequestNotification).to receive(:with).with(demo_request:,
                                                            locale: I18n.locale.to_s).and_return(notification)
      allow(notification).to receive(:deliver)
      demo_request.send(:notify_demo_request)
      expect(notification).to have_received(:deliver).with(demo_request)
    end
  end
end
