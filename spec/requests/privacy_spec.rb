# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Privacy page', type: :request do
  before do
    create(:language, :english)
    allow(ENV).to receive(:fetch).and_call_original
    %w[RESPONSIBLE ADDRESS EMAIL].each do |key|
      allow(ENV).to receive(:fetch).with("DELTA_POS_PRIVACY_#{key}", '').and_return('')
    end
  end

  it 'provides a public readable draft and resolves every contents link' do
    get privacy_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css('h1').length).to eq(1)
    expect(document.at_css('[data-privacy-draft]')).to be_present
    document.css('.privacy-index a').each do |link|
      expect(document.at_css(link['href'])).to be_present
    end
    expect(document.at_css('a[href^="mailto:"]')).to be_nil
  end

  it 'renders escaped contact information while retaining the draft status' do
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_RESPONSIBLE', '').and_return('Operator <script>test</script>')
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_ADDRESS', '').and_return('Example address')
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_EMAIL', '').and_return('privacy@example.invalid')
    get privacy_path

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[data-privacy-draft]')).to be_present
    expect(document.at_css('.privacy-details script')).to be_nil
    expect(document.at_css('a[href="mailto:privacy@example.invalid"]')).to be_present
  end

  it 'does not turn an invalid contact into an executable link' do
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_EMAIL', '').and_return('javascript:alert(1)')
    get privacy_path

    expect(response.body).to include('data-privacy-draft')
    expect(Nokogiri::HTML(response.body).at_css('a[href^="mailto:"]')).to be_nil
  end

  %w[es ko].each do |locale|
    it "renders the #{locale} translation" do
      cookies[:terminal_language] = locale
      get privacy_path

      expect(response.body).to include(I18n.t('privacy.title', locale:))
      expect(response.body).not_to include('translation missing')
    end
  end
end
