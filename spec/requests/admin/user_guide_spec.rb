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

  it 'keeps all detailed Spanish procedures available under English and Korean chapter headings' do
    %i[en ko].each do |locale|
      I18n.with_locale(locale) do
        Admin::GuideController::SECTION_ORDER.each do |section|
          spanish = I18n.t("admin.user_manual.sections.#{section}", locale: :es)
          translated = I18n.t("admin.user_manual.sections.#{section}", locale:)
          expect(translated[:title]).to be_present
          expect(translated[:description]).to be_present
          expect(translated[:topics]).to eq([])
          expect(spanish[:topics]).not_to be_empty
        end
      end
    end
  end

  it 'provides a distinct local SVG for every step-by-step procedure' do
    get admin_guide_path

    page = Nokogiri::HTML(response.body)
    expected = Admin::GuideController::SECTION_ORDER.sum do |section|
      I18n.t("admin.user_manual.sections.#{section}", locale: :es).fetch(:topics).sum do |topic|
        topic.fetch(:tasks).size
      end
    end

    figures = page.css('figure.guide-diagram')
    expect(figures.size).to eq(expected)
    expect(figures.size).to eq(78)
    expect(page.css('article[data-user-guide-target="topic"]').size).to eq(35)
    expect(page.at_css('img[alt*="Visual learning path"]')).to be_present
    expect(page.at_css('dialog[data-user-guide-target="viewer"]')).to be_present
    expect(page.css('button[data-action="click->user-guide#openIllustration"]').size).to eq(78)

    figures.each do |figure|
      image = figure.at_css('img')
      file = Rails.root.join('app/assets/images/guide',
                             "#{figure['data-topic']}-#{figure['data-procedure']}.svg")
      expect(image['src']).to include('.svg')
      expect(image['alt']).to be_present
      expect(File).to exist(file)
      xml = File.read(file)
      expect(xml).to include('<svg', 'viewBox=', 'aria-labelledby=', '01 · LOCALIZA', '02 · REALIZA')
      expect(xml).not_to include('<script', 'http://cdn', 'https://cdn')
    end
  end

  it 'requires authentication' do
    sign_out user
    get admin_guide_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
