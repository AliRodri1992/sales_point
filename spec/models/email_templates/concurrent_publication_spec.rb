# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe 'Concurrent email template publication', type: :model do
  it 'serializes overlapping PostgreSQL locks and creates only one publication audit' do
    template = EmailTemplate.create!(
      key: 'overlapping_notice', name: 'Overlapping notice', category: 'security',
      locale: 'es', subject: 'Notice', html_body: '<p>Notice</p>',
      text_body: 'Notice', status: 'draft', enabled: false
    )
    draft = template.new_draft!(actor: nil)
    locked = Queue.new
    started = Queue.new
    release = Queue.new

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
    Timeout.timeout(10) { locked.pop }

    second = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET application_name = 'email_template_publication_overlap'")
        started << true
        version = EmailTemplateVersion.find(draft.id)
        version.publish!(actor: nil)
        :unexpected_publication
      rescue ActiveRecord::StaleObjectError
        :conflict
      ensure
        connection.execute('RESET application_name')
      end
    end
    Timeout.timeout(10) { started.pop }
    Timeout.timeout(10) do
      loop do
        waiting = ActiveRecord::Base.connection.select_value(
          "SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE application_name = " \
          "'email_template_publication_overlap' AND wait_event_type = 'Lock')"
        )
        break if ActiveModel::Type::Boolean.new.cast(waiting)

        sleep 0.02
      end
    end
    release << true

    expect(first.value).to be_truthy
    expect(second.value).to eq(:conflict)
    expect(template.reload.published_version_id).to eq(draft.id)
    expect(template.versions.where(status: 'published').count).to eq(1)
    expect(template.audits.where(action: 'published').count).to eq(1)
  ensure
    release << true if release && first&.alive?
    [first, second].compact.each do |thread|
      thread.join(2)
      thread.kill if thread.alive?
    end
  end
end
