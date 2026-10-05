# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequest, type: :model do
  subject(:demo_request){build(:demo_request)}

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:company) }
    it { is_expected.to validate_presence_of(:phone) }
    it 'rejects invalid email' do demo_request.email='invalid'; expect(demo_request).to be_invalid end
    it 'rejects short name and company' do demo_request.name='A'; demo_request.company='A'; expect(demo_request).to be_invalid end
    it 'rejects invalid phone' do demo_request.phone='123'; expect(demo_request).to be_invalid end
    it 'allows blank message' do demo_request.message=nil; expect(demo_request).to be_valid end
    it 'rejects oversized message' do demo_request.message='A'*2_001; expect(demo_request).to be_invalid end
  end

  describe 'status' do
    it 'defines statuses' do
      expect(described_class.statuses).to eq('pending'=>'pending','contacted'=>'contacted','completed'=>'completed')
    end
    it 'defaults to pending' do expect(described_class.new.status).to eq('pending') end
  end

  describe 'callbacks' do
    it 'delivers notification' do
      notification=instance_double(DemoRequestNotification)
      allow(DemoRequestNotification).to receive(:with).with(demo_request:,locale:I18n.locale.to_s).and_return(notification)
      allow(notification).to receive(:deliver)
      demo_request.send(:notify_demo_request)
      expect(notification).to have_received(:deliver).with(demo_request)
    end
  end
end