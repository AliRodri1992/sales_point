# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Concurrent email template publication', type: :model do
  it 'serializes overlapping transactions and persists only one publication audit' do
    template = EmailTemplate.create!(
      key: 'overlapping_notice', name: 'Overlapping notice', category: 'security',
      locale: 'es', subject: 'Notice', html_body: '<p>Notice</p>',
      text_body: 'Notice', status: 'draft', enabled: false
    )
    draft = template.new_draft!(actor: nil)
    locked = Queue.new
    attempted = Queue.new
    release = Queue.new

    allow_any_instance_of(EmailTemplate).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      attempted << true if Thread.current[:second_email_publisher]
      method.call(*args, &block)
    end

    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        EmailTemplate.find(template.id).with_lock do
          locked << true
          release.pop
          version = EmailTemplateVersion.find(draft.id)
          version.publish!(actor: nil)
          version.email_template.audit!(action: 'published', actor: nil, version:)
        end
      end
    end
    locked.pop

    second = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        version = EmailTemplateVersion.find(draft.id)
        Thread.current[:second_email_publisher] = true
        version.publish!(actor: nil)
        :unexpected_publication
      rescue ActiveRecord::StaleObjectError
        :conflict
      end
    end
    attempted.pop
    release << true

    expect(first.value).to be_truthy
    expect(second.value).to eq(:conflict)
    expect(template.reload.published_version_id).to eq(draft.id)
    expect(template.versions.where(status: 'published').count).to eq(1)
    expect(template.audits.where(action: 'published').count).to eq(1)
  ensure
    release << true if release && first&.alive?
    [first, second].compact.each(&:join)
  end
end
