# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Products module browser flows', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: administrator)
    create(:user_role, user: administrator,
                       system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'selects an unsaved variant and presentation for a new barcode in the same form' do
    visit new_admin_product_path
    fill_in 'product_name', with: 'Single form catalog'
    fill_in 'product_code', with: 'SINGLE-FORM-CATALOG'
    fill_in 'product_price', with: '42'

    click_button 'Add variant'
    within('#product-variants [data-nested-catalog-row]') do
      find('input[name$="[name]"]').set('Large')
      find('input[name$="[sku]"]').set('SINGLE-FORM-LARGE')
    end

    click_button 'Add presentation'
    within('#product-presentations [data-nested-catalog-row]') do
      find('input[name$="[name]"]').set('Box')
      find('input[name$="[units]"]').set('6')
    end

    click_button 'Add barcode'
    within('#product-barcodes [data-nested-catalog-row]') do
      find('input[name$="[value]"]').set('LARGE-BOX-42')
      find('select[name$="[product_variant_id]"]', visible: :all)
        .find('option', text: 'Large', visible: :all).select_option
      find('select[name$="[product_presentation_id]"]', visible: :all)
        .find('option', text: 'Box', visible: :all).select_option
    end

    # The actual browser form must send the temporary association keys.
    variant_select = find('#product-barcodes select[name$="[product_variant_id]"]', visible: :all)
    presentation_select = find('#product-barcodes select[name$="[product_presentation_id]"]', visible: :all)
    variant_key = find('#product-variants [data-nested-catalog-rows] input[name$="[client_key]"]', visible: :all).value
    presentation_key = find('#product-presentations [data-nested-catalog-rows] input[name$="[client_key]"]',
                            visible: :all).value
    expect(variant_select.value).to eq("new:#{variant_key}")
    expect(presentation_select.value).to eq("new:#{presentation_key}")

    # Editing another field must never clear already-selected temporary options.
    fill_in 'product_description', with: 'Selections survive unrelated typing'
    expect(variant_select.value).to eq("new:#{variant_key}")
    expect(presentation_select.value).to eq("new:#{presentation_key}")

    click_button 'Create product'
    expect(page).to have_current_path(admin_products_path, ignore_query: true)

    product = organization.products.find_by!(code: 'SINGLE-FORM-CATALOG')
    barcode = product.product_barcodes.find_by!(value: 'LARGE-BOX-42')
    expect(barcode.product_variant.name).to eq('Large')
    expect(barcode.product_presentation.name).to eq('Box')
  end

  scenario 'keeps compact advanced filters and explains inverted prices on mobile' do
    page.current_window.resize_to(390, 844)
    visit admin_products_path

    expect(page).to have_css('.products-filters__actions .products-filters__apply')
    find('details.products-filters__advanced summary').click
    fill_in 'products_min_price', with: '200'
    fill_in 'products_max_price', with: '100'
    click_button 'Apply filters'

    expect(page).to have_css('#products_price_range_error', visible: true)
    expect(page).to have_css('#products_min_price[aria-invalid="true"]')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
  end
end
