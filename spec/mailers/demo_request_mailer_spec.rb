# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequestMailer, type: :mailer do
  let(:demo_request) { build(:demo_request) }

  describe '#new_request' do
    it 'builds the notification email with the request data' do
      mail = described_class.with(demo_request:, locale: 'en').new_request

      expect(mail.to).to eq(['ali.rodri.vasquez@gmail.com'])
      expect(mail.from).to eq([demo_request.email])
      expect(mail.subject).to eq(I18n.t('demo_request_mailer.new_request.subject'))
      expect(mail.html_part.body.to_s).to include(demo_request.name, demo_request.company, demo_request.email)
      expect(mail.html_part.body.to_s).to include('Delta POS')
      expect(mail.text_part.body.to_s).to include(demo_request.name, demo_request.company)
    end

    it 'uses the locale passed by the notification' do
      mail = described_class.with(demo_request:, locale: 'ko').new_request

      expect(mail.subject).to eq('새 데모 신청 - Delta POS')
      expect(mail.html_part.body.to_s).to include('신청자 정보')
      expect(mail.html_part.body.to_s).to include('비즈니스 정보')
    end

    it 'does not depend on Tailwind or JavaScript' do
      mail = described_class.with(demo_request:, locale: 'en').new_request
      html = mail.html_part.body.to_s

      expect(html).not_to include('cdn.tailwindcss.com')
      expect(html).not_to include('<script')
    end
  end
end
