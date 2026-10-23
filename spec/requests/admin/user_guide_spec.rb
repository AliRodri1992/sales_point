# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Delta POS user guide', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    sign_in user
  end

  it 'renders an actual manual, with navigable chapters and searchable procedures' do
    get admin_guide_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.text).to include('System user guide')
    expect(document.css('section[data-user-guide-target="section"]').size).to eq(7)
    expect(document.css('article[data-user-guide-target="topic"]').size).to eq(35)
    expect(document.at_css('#guide-suppliers')).to be_present
    expect(document.at_css('#guide-categories ol li')).to be_present
    expect(document.at_css('#guide-products ol li')).to be_present
    expect(document.at_css('input[data-action="input->user-guide#filter"]')).to be_present
    expect(document.at_css("a[href='#{admin_guide_path}']")).to be_present
  end

  it 'explains concrete create, edit and archive operations instead of navigation cards only' do
    get admin_guide_path

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('#guide-products').text).to include('Dar de alta un producto')
    expect(page.at_css('#guide-products').text).to include('Eliminar un producto')
    expect(page.at_css('#guide-categories').text).to include('Dar de alta una categoría')
    expect(page.at_css('#guide-categories').text).to include('Eliminar una categoría')
    expect(page.at_css('#guide-onboarding').text).to include('Paso 5:')
    expect(page.at_css('#guide-supplier_invoices').text).to include('CFDI')
    expect(page.at_css('#guide-coming_soon').css('a')).to be_empty
  end

  it 'provides valid ids and steps for every chapter in the Spanish source manual' do
    ids = Admin::GuideController::SECTION_ORDER.flat_map do |section|
      chapter = I18n.t("admin.user_manual.sections.#{section}", locale: :es)
      expect(chapter.fetch(:title)).to be_present
      chapter.fetch(:topics).map do |topic|
        expect(topic.fetch(:tasks)).not_to be_empty
        topic.fetch(:tasks).each { |task| expect(task.fetch(:steps)).not_to be_empty }
        topic.fetch(:id)
      end
    end

    expect(ids.uniq).to eq(ids)
  end

  it 'requires authentication' do
    sign_out user
    get admin_guide_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
