# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequestDeliveryGuard do
  subject(:guarded_mailer) do
    instance = fake_mailer_class.new
    allow(instance).to receive(:params).and_return(parameters)
    allow(instance).to receive(:mail).and_return(message)
    instance
  end

  let(:fake_mailer_class) do
    Class.new do
      def self.after_action(*) = nil

      include DemoRequestDeliveryGuard

      def params = {}
      def mail = nil
    end
  end
  let(:message) { instance_double(Mail::Message) }
  let(:parameters) { {} }

  it 'does not suppress messages without a demo request parameter' do
    expect(message).not_to receive(:perform_deliveries=)

    guarded_mailer.send(:suppress_deleted_demo_request_delivery)
  end

  it 'ignores parameters that are not DemoRequest records' do
    allow(guarded_mailer).to receive(:params).and_return(demo_request: 'invalid')
    expect(message).not_to receive(:perform_deliveries=)

    guarded_mailer.send(:suppress_deleted_demo_request_delivery)
  end

  context 'with a live demo request' do
    let(:parameters) { { demo_request: build(:demo_request) } }

    it 'preserves delivery' do
      expect(message).not_to receive(:perform_deliveries=)

      guarded_mailer.send(:suppress_deleted_demo_request_delivery)
    end
  end

  context 'with an archived demo request' do
    let(:parameters) { { demo_request: build(:demo_request, deleted_at: Time.current) } }

    it 'disables delivery of the stale message' do
      expect(message).to receive(:perform_deliveries=).with(false)

      guarded_mailer.send(:suppress_deleted_demo_request_delivery)
    end
  end
end
