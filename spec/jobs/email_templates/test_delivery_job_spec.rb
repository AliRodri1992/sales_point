# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::TestDeliveryJob, type: :job do
  let(:actor) { create(:user) }
  let(:template) do
    EmailTemplate.create!(
      key: 'delivery_status', name: 'Delivery status', locale: 'es', category: 'security',
      subject: 'Notification', html_body: '<p>Notification</p>', text_body: 'Notification',
      status: 'draft', enabled: false
    )
  end

  it 'records delivery only after the email has been sent' do
    template.new_draft!(actor:).publish!(actor:)
    expect do
      described_class.perform_now(template.id, actor.id, 'recipient@example.org')
    end.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(template.audits.where(action: 'test_delivered', actor:)).to exist
    expect(template.audits.where(action: 'test_failed', actor:)).not_to exist
  end
end
