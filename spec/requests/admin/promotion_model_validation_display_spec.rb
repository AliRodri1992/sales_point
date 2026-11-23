# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Promotion model validation messages', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, user:, organization:)
    create(:currency, code: 'MXN')
    sign_in user
  end

  it 'uses model validations rather than browser-native validation' do
    get new_admin_promotion_path
    form = Nokogiri::HTML(response.body).at_css('form.promotion-form')
    expect(form).to be_present
    expect(form.has_attribute?('novalidate')).to be(true)
    expect(form.at_css('#promotion_name')['required']).to be_nil
    expect(form.at_css('#promotion_name')['maxlength']).to be_nil
  end

  it 'displays field name followed by the model validation description' do
    post admin_promotions_path, params: { promotion: { name: '', currency: 'MXN', usage_limit: 0 } }

    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    errors = page.css('[data-server-field-error]')
    name = errors.find { |node| node['data-validation-attribute'] == 'name' }
    usage = errors.find { |node| node['data-validation-attribute'] == 'usage_limit' }
    expect(name.text.strip).to start_with('Promotion name ')
    expect(usage.text.strip).to start_with('Total usage limit ')
    expect(page.at_css('#promotion_name')['aria-invalid']).to eq('true')
    expect(page.at_css('form.promotion-form').has_attribute?('novalidate')).to be(true)
    expect(organization.promotions).to be_empty
  end

  it 'uses model-level errors and specific field labels for nested benefits and conditions' do
    post admin_promotions_path, params: { promotion: {
      name: 'Invalid rules', currency: 'MXN',
      promotion_benefits_attributes: { '0' => { kind: 'percentage', value: 125 } },
      promotion_conditions_attributes: { '0' => { kind: 'min_quantity', quantity: 0 } }
    } }

    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    messages = page.css('[data-server-field-error]').map { |node| node.text.strip }
    expect(messages).to include(a_string_starting_with('Benefit value '))
    expect(messages).to include(a_string_starting_with('Minimum quantity '))
    expect(page.at_css('#campaign-benefits [aria-invalid="true"]')).to be_present
    expect(page.at_css('#campaign-conditions [aria-invalid="true"]')).to be_present
    expect(organization.promotions).to be_empty
  end


  context 'with the user language set to Spanish' do
    let(:user) { create(:user, :spanish, system_roles: [create(:system_role, :system, code: 'administrator')]) }

    let(:invalid_period) do
      { starts_at: '2026-11-13T12:56', ends_at: '2026-11-11T00:00' }
    end

    def expect_period_error
      expect(response).to have_http_status(:unprocessable_content)
      page = Nokogiri::HTML(response.body)
      error = page.at_css('[data-server-field-error][data-validation-attribute="ends_at"]')
      expect(error).to be_present
      expect(error.text.strip).to eq('Fecha y hora de fin debe ser posterior a la de inicio.')
      expect(page.at_css('#promotion_ends_at')['aria-invalid']).to eq('true')
      expect(page.at_css('form.promotion-form').has_attribute?('novalidate')).to be(true)
    end

    it 'shows the descriptive ActiveRecord validation when creating a promotion' do
      post admin_promotions_path, params: { promotion: {
        name: 'Oferta noviembre', currency: 'MXN', **invalid_period
      } }

      expect_period_error
      expect(organization.promotions).to be_empty
    end

    it 'shows the same validation when editing a promotion, without saving an invalid period' do
      promotion = organization.promotions.create!(name: 'Oferta existente', currency: 'MXN')

      patch admin_promotion_path(promotion), params: { promotion: invalid_period }

      expect_period_error
      expect(promotion.reload.starts_at).to be_nil
      expect(promotion.ends_at).to be_nil
    end

    it 'rejects an end date equal to the start date using the same message' do
      post admin_promotions_path, params: { promotion: {
        name: 'Oferta misma hora', currency: 'MXN',
        starts_at: '2026-11-13T12:56', ends_at: '2026-11-13T12:56'
      } }

      expect_period_error
    end

    it 'keeps malformed dates under the existing invalid-date validation' do
      promotion = organization.promotions.build(name: 'Fecha mal formada', currency: 'MXN',
                                                starts_at: '2026-11-13T12:56', ends_at: 'not-a-date')

      expect(promotion).not_to be_valid
      expect(promotion.errors.details[:ends_at].map { |detail| detail[:error] }).to include(:invalid)
      expect(promotion.errors.details[:ends_at].map { |detail| detail[:error] }).not_to include(:after_start)
    end
  end

  it 'retains the field names in Spanish and Korean translations' do
    expect(I18n.t('errors.attributes.promotion.name', locale: :es)).to eq('Nombre de la promoción')
    expect(I18n.t('errors.attributes.promotion_benefit.value', locale: :es)).to eq('Valor del beneficio')
    expect(I18n.t('errors.attributes.promotion_condition.quantity', locale: :ko)).to eq('최소 수량')
  end
end
