# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier, purchasing and finance permission localization', type: :request do
  ATTRIBUTES = %w[name description].freeze

  let(:user) { create(:user, :english) }

  before do
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    create(:permission, code: 'suppliers.fiscal.view', name: 'View supplier fiscal information',
                        description: 'View supplier fiscal information.', module_name: 'Proveedores')
    create(:permission, code: 'purchases.view', name: 'View purchases',
                        description: 'View purchases within the organization.', module_name: 'Compras')
    create(:permission, code: 'accounts_payable.banks.reveal', name: 'Reveal bank account numbers',
                        description: 'Reveal bank account numbers.', module_name: 'Cuentas por pagar')
    sign_in user
  end

  %i[es en ko].each do |locale|
    it "renders localized permission names and descriptions in #{locale}" do
      language = Language.find_by(code: locale) || create(:language, code: locale, name: locale, flag_iso: 'mx')
      user.update!(language:)
      get new_system_role_path

      expect(response).to have_http_status(:ok)
      %w[suppliers_fiscal_view purchases_view accounts_payable_banks_reveal].each do |key|
        ATTRIBUTES.each do |field|
          expect(response.body).to include(I18n.t("admin.system_roles.permissions.#{key}.#{field}", locale:))
        end
      end
    end
  end
end
