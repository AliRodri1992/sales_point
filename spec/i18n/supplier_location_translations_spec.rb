# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier address location translations', type: :i18n do
  it 'provides searching and confirmation messages in all supported languages' do
    expected = {
      es: 'Buscando la ubicación del domicilio…',
      en: 'Looking up the address location…',
      ko: '주소의 위치를 검색하고 있습니다…'
    }

    expected.each do |locale, message|
      I18n.with_locale(locale) do
        searching = I18n.t('admin.supplier_details.address_form.location_searching')
        expect(searching).to eq(message)
        expect(I18n.t('activerecord.errors.models.address.attributes.base.invalid_location_confirmation'))
          .not_to include('Translation missing')
      end
    end
  end
end
