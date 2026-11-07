# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplateNotification, type: :model do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:template) do
    EmailTemplate.create!(organization:, key: 'payment_notice', name: 'Payment notice',
                          category: 'transactional', locale: 'es', status: 'draft',
                          subject: 'Payment', html_body: '<p>Payment</p>', text_body: 'Payment')
  end

  it 'creates a panel notification for an email template event' do
    expect do
      described_class.with(action: 'created', record: template, user:)
                     .deliver(user, enqueue_job: false)
    end.to change { user.notifications.count }.by(1)

    notification = user.notifications.last
    expect(notification.type).to eq('EmailTemplateNotification::Notification')
    expect(notification.event.record).to eq(template)
    expect(notification.event.message).to eq(
      I18n.t('admin.shared.notifications.email_template.created', name: template.name)
    )
  end

  it 'remains visible after the email template is archived' do
    described_class.with(action: 'archived', record: template, user:)
                   .deliver(user, enqueue_job: false)
    template.update!(status: 'archived', enabled: false)

    expect(user.notifications.last.event.record).to eq(template)
    expect(user.unread_notifications.count).to eq(1)
  end
end
