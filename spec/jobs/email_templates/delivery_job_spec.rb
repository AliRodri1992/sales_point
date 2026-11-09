# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::DeliveryJob, type: :job do
  let(:ciphertext) do
    EmailTemplates::EncryptedPayload.encrypt(
      template_id: -1, recipient: 'buyer@example.org', values: {}
    )
  end

  it 'does not retry permanent template errors' do
    expect do
      expect { described_class.perform_now(ciphertext) }.to raise_error(ActiveRecord::RecordNotFound)
    end.not_to have_enqueued_job(described_class)
  end

  it 'retries connection refusal before SMTP acceptance' do
    allow(EmailTemplates::TransactionalMailer).to receive(:notification).and_raise(Errno::ECONNREFUSED)

    expect { described_class.perform_now(ciphertext) }.to have_enqueued_job(described_class)
  end

  it 'does not blindly retry an ambiguous SMTP read timeout' do
    allow(EmailTemplates::TransactionalMailer).to receive(:notification).and_raise(Net::ReadTimeout)

    expect do
      expect { described_class.perform_now(ciphertext) }.to raise_error(Net::ReadTimeout)
    end.not_to have_enqueued_job(described_class)
  end
end
