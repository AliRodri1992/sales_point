# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#sidebar_item_active?' do
    before { allow(helper).to receive(:controller_name).and_return(controller_name) }

    context 'when the controller matches' do
      let(:controller_name) { 'dashboard' }

      it 'returns true' do
        expect(helper.sidebar_item_active?('dashboard')).to be(true)
      end
    end

    context 'when the controller does not match' do
      let(:controller_name) { 'dashboard' }

      it 'returns false' do
        expect(helper.sidebar_item_active?('languages')).to be(false)
      end
    end

    it 'accepts the controller name as a string' do
      allow(helper).to receive(:controller_name).and_return('languages')
      expect(helper.sidebar_item_active?('languages')).to be(true)
    end
  end

  describe '#sidebar_link_classes' do
    before { allow(helper).to receive(:controller_name).and_return(controller_name) }

    context 'with the default variant' do
      let(:controller_name) { 'dashboard' }

      it 'highlights the item when active' do
        classes = helper.sidebar_link_classes('dashboard')
        expect(classes).to include('bg-emerald-700', 'font-semibold', 'text-white')
      end

      it 'highlights only the matching item (only one active)' do
        expect(helper.sidebar_link_classes('dashboard')).to include('bg-emerald-700')
        expect(helper.sidebar_link_classes('languages')).not_to include('bg-emerald-700')
      end

      it 'does not highlight when inactive' do
        classes = helper.sidebar_link_classes('languages')
        expect(classes).to include('text-slate-600', 'hover:bg-emerald-50')
        expect(classes).not_to include('bg-emerald-700', 'text-white')
      end
    end

    context 'with the submenu variant' do
      let(:controller_name) { 'languages' }

      it 'uses submenu padding (py-2)' do
        expect(helper.sidebar_link_classes('languages', variant: :submenu)).to include('py-2')
      end

      it 'highlights the item when active' do
        expect(
          helper.sidebar_link_classes('languages', variant: :submenu)
        ).to include('bg-emerald-700', 'font-semibold', 'text-white')
      end

      it 'keeps slate-500 coloring when inactive' do
        classes = helper.sidebar_link_classes('dashboard', variant: :submenu)
        expect(classes).to include('text-slate-500', 'hover:bg-emerald-50')
        expect(classes).not_to include('bg-emerald-700')
      end
    end
  end

  describe '#sidebar_section_open?' do
    before { allow(helper).to receive(:controller_name).and_return(controller_name) }

    context 'when the current controller belongs to the section' do
      let(:controller_name) { 'languages' }

      it 'returns true' do
        expect(helper.sidebar_section_open?('languages')).to be(true)
      end

      it 'returns true when any of multiple controllers match' do
        expect(helper.sidebar_section_open?('dashboard', 'languages')).to be(true)
      end
    end

    context 'when the current controller is outside the section' do
      let(:controller_name) { 'dashboard' }

      it 'returns false' do
        expect(helper.sidebar_section_open?('languages')).to be(false)
      end
    end

    it 'expands the Catalogs parent only for its child controllers' do
      allow(helper).to receive(:controller_name).and_return('languages')
      expect(helper.sidebar_section_open?('languages')).to be(true)

      allow(helper).to receive(:controller_name).and_return('dashboard')
      expect(helper.sidebar_section_open?('languages')).to be(false)
    end
  end

  describe '#sidebar grouped navigation' do
    it 'keeps Suppliers active throughout its address and banking dossier' do
      allow(helper).to receive(:controller_name).and_return('supplier_bank_accounts')
      expect(helper.sidebar_item_active?('suppliers')).to be(true)
      expect(helper.sidebar_item_active?('account_payables')).to be(false)
    end

    it 'highlights payables for invoice and payment submodules' do
      allow(helper).to receive(:controller_name).and_return('supplier_invoices')
      expect(helper.sidebar_item_active?('account_payables')).to be(true)
      expect(helper.sidebar_item_active?('suppliers')).to be(false)
    end

    it 'keeps nested purchase workflows in the purchasing section' do
      allow(helper).to receive(:controller_name).and_return('goods_receipts')
      expect(helper.sidebar_item_active?('purchase_orders')).to be(true)
    end

    it 'marks the current link using Delta Emerald, without invalid classes' do
      allow(helper).to receive(:controller_name).and_return('supplier_addresses')
      expect(helper.sidebar_link_classes('suppliers')).to include('bg-emerald-700', 'text-white')
      expect(helper.sidebar_link_classes('products')).not_to include('text-slate-900}')
    end

    it 'shows a generic role when a user has no assigned roles' do
      user = create(:user)
      expect(helper.sidebar_role_label(user)).to eq(I18n.t('admin.shared.sidebar.role_user'))
    end

    it 'shows the actual active role name in the account menu' do
      user = create(:user)
      role = create(:system_role, :system, name: 'Supervisor', code: 'supervisor')
      create(:user_role, user:, system_role: role)

      expect(helper.sidebar_role_label(user)).to eq('Supervisor')
      expect(user.display_role_name).to eq('Supervisor')
    end
  end

  describe '#form_state_classes' do
    let(:language) { Language.new }

    context 'when the attribute has no errors' do
      it 'returns the slate border classes' do
        classes = helper.form_state_classes(language, :name)
        expect(classes).to include('border-slate-200', 'bg-slate-50')
        expect(classes).not_to include('rose')
      end
    end

    context 'when the attribute has errors' do
      before { language.errors.add(:name, :blank) }

      it 'returns the rose border classes' do
        classes = helper.form_state_classes(language, :name)
        expect(classes).to include('border-rose-500', 'bg-rose-50')
        expect(classes).not_to include('slate-200')
      end
    end
  end

  describe '#breadcrumb_items' do
    before do
      allow(helper).to receive(:params).and_return(
        ActionController::Parameters.new(controller: 'admin/products', action: action)
      )
    end

    context 'when creating a product' do
      let(:action) { 'new' }

      it 'uses the new product title' do
        assign(:product, Product.new)

        labels = helper.breadcrumb_items.pluck(:label)

        expect(labels).to eq([
                               t('admin.breadcrumbs.home'),
                               t('admin.breadcrumbs.products'),
                               t('admin.products.new.title')
                             ])
      end
    end

    context 'when editing a product' do
      let(:action) { 'edit' }
      let(:product) { instance_double(Product, persisted?: true, name: 'Coca-Cola') }

      it 'uses the product name' do
        allow(helper).to receive(:current_product).and_return(product)

        labels = helper.breadcrumb_items.pluck(:label)

        expect(labels.last).to eq('Coca-Cola')
      end
    end
  end

  describe '#error_message_for' do
    let(:language) { Language.new }

    it 'returns an empty string when the object is nil' do
      expect(helper.error_message_for(nil, :name)).to eq('')
    end

    context 'when the attribute has no errors' do
      it 'returns an empty string' do
        expect(helper.error_message_for(language, :name)).to eq('')
      end
    end

    context 'when the attribute has errors' do
      before { language.errors.add(:name, :blank) }

      it 'returns a paragraph with the full message including the field name' do
        result = helper.error_message_for(language, :name)
        expect(result).to have_css('p.mt-1.text-xs.text-rose-600', text: /Name/i)
      end
    end
  end
  describe '#error_message_for on duplicate primary addresses' do
    it 'shows the Spanish message directly beneath the primary control' do
      I18n.with_locale(:es) do
        address = build(:address)
        address.errors.add(:primary, :taken)

        expect(helper.error_message_for(address, :primary)).to have_css(
          'p[data-server-field-error]',
          text: 'La dirección principal ya está asignada a otra dirección de este tipo.'
        )
      end
    end
  end

  describe '#user_avatar_colors and #user_avatar_style' do
    let(:user) { create(:user) }

    it 'returns the selected avatar color classes and inline style' do
      expect(helper.user_avatar_colors(user)).to eq(helper.user_avatar_theme(user)[:classes])
      expect(helper.user_avatar_style(user)).to eq(helper.user_avatar_theme(user)[:style])
    end
  end

  describe '#onboarding_progress_for_current_user' do
    it 'returns nil when there is no current user' do
      allow(helper).to receive(:current_user).and_return(nil)

      expect(helper.onboarding_progress_for_current_user).to be_nil
    end

    it 'returns nil when the current user has no active organization' do
      organizations = double(active_records: double(first: nil))
      user = double(organizations:)

      allow(helper).to receive(:current_user).and_return(user)

      expect(helper.onboarding_progress_for_current_user).to be_nil
    end

    it 'returns nil when onboarding is already complete' do
      organization = double(onboarding_completed?: true)
      organizations = double(active_records: double(first: organization))
      user = double(organizations:)

      allow(helper).to receive(:current_user).and_return(user)

      expect(helper.onboarding_progress_for_current_user).to be_nil
    end
  end

  describe '#onboarding_pending?' do
    it 'returns false when no progress is available' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(nil)

      expect(helper.onboarding_pending?).to be(false)
    end

    it 'returns true while onboarding progress is below completion' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(percentage: 75)

      expect(helper.onboarding_pending?).to be(true)
    end

    it 'returns false when onboarding is complete' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(percentage: 100)

      expect(helper.onboarding_pending?).to be(false)
    end
  end

  describe '#onboarding_section_complete?' do
    it 'treats a missing progress object as complete' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(nil)

      expect(helper.onboarding_section_complete?(:profile)).to be(true)
    end

    it 'checks the requested section percentage' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(
        sections: [{ key: 'profile', percentage: 100 }, { key: 'billing', percentage: 50 }]
      )

      expect(helper.onboarding_section_complete?(:profile)).to be(true)
      expect(helper.onboarding_section_complete?(:billing)).to be(false)
      expect(helper.onboarding_section_complete?(:unknown)).to be(false)
    end

    it 'uses the default percentage for a section without one' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(
        sections: [{ key: 'profile' }]
      )

      expect(helper.onboarding_section_complete?(:profile)).to be(true)
    end
  end

  describe '#user_status_badge' do
    it 'uses distinct classes for suspended and blocked users' do
      expect(helper.user_status_badge('suspended')).to include('bg-amber-50', 'text-amber-700')
      expect(helper.user_status_badge('blocked')).to include('bg-rose-50', 'text-rose-700')
    end

    it 'uses neutral classes for an unknown status' do
      expect(helper.user_status_badge('unknown')).to include('bg-slate-100', 'text-slate-600')
    end
  end
end
