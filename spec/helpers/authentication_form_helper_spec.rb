# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthenticationFormHelper, type: :helper do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DELTA_POS_TERMS_URL', '').and_return('')
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_URL', '').and_return('')
  end

  it 'does not fabricate links when approved documents are unavailable' do
    expect(helper.authentication_documents_available?).to be(false)
    expect(helper.authentication_document_reference(:terms)).not_to include('<a')
  end

  it 'opens configured HTTPS documents separately without discarding the form' do
    allow(ENV).to receive(:fetch).with('DELTA_POS_TERMS_URL', '').and_return('https://example.com/terms')
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_URL', '').and_return('https://example.com/privacy')

    expect(helper.authentication_documents_available?).to be(true)
    link = Nokogiri::HTML.fragment(helper.authentication_document_reference(:terms)).at_css('a')
    expect(link['href']).to eq('https://example.com/terms')
    expect(link['target']).to eq('_blank')
    expect(link['rel']).to include('noopener', 'noreferrer')
  end

  it 'does not render insecure or executable document references' do
    urls = ['javascript:alert(1)', 'http://example.com/terms', 'https://user:password@example.com', 'https://[invalid']
    urls.each do |url|
      allow(ENV).to receive(:fetch).with('DELTA_POS_TERMS_URL', '').and_return(url)
      expect(helper.authentication_document_url(:terms)).to be_nil
    end
  end
end
