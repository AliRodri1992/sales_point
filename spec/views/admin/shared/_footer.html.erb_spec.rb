# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'admin/shared/_footer', type: :view do
  before do
    allow(view).to receive(:authentication_document_url).with(:privacy).and_return('/privacy')
    allow(view).to receive(:authentication_document_url).with(:terms).and_return(nil)
  end

  it 'links to privacy and explains missing terms without placeholder links' do
    render partial: 'admin/shared/footer'

    document = Nokogiri::HTML.fragment(rendered)
    expect(document.at_css('a[href="/privacy"]')).to be_present
    expect(document.css('a[href="#"]')).to be_empty
    expect(document.text).to include(I18n.t('admin.shared.footer.terms_unavailable'))
  end

  it 'links to the configured terms document' do
    allow(view).to receive(:authentication_document_url).with(:terms).and_return('https://example.com/terms')
    render partial: 'admin/shared/footer'

    expect(Nokogiri::HTML.fragment(rendered).at_css('a[href="https://example.com/terms"]')).to be_present
    expect(rendered).not_to include(I18n.t('admin.shared.footer.terms_unavailable'))
  end
end
