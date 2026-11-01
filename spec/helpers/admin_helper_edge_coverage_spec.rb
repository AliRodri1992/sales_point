# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Administration helper fallback and validation branches', type: :helper do
  describe '#onboarding_pending?' do
    it 'rejects missing or complete onboarding progress' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(nil)
      expect(helper.onboarding_pending?).to be_falsey
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(percentage: 100)
      expect(helper.onboarding_pending?).to be(false)
    end

    it 'reports partial progress as pending' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(percentage: 30)
      expect(helper.onboarding_pending?).to be(true)
    end
  end

  describe '#onboarding_section_complete?' do
    it 'treats missing progress as complete' do
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(nil)
      expect(helper.onboarding_section_complete?(:company)).to be(true)
    end

    it 'accepts completed sections and rejects incomplete ones' do
      progress = { sections: [{ key: :company, percentage: 100 }, { key: :fiscal, percentage: 40 }] }
      allow(helper).to receive(:onboarding_progress_for_current_user).and_return(progress)
      expect(helper.onboarding_section_complete?(:company)).to be(true)
      expect(helper.onboarding_section_complete?(:fiscal)).to be(false)
    end
  end

  describe '#form_state_classes' do
    it 'uses a red border only for fields with errors' do
      model = double(errors: { name: ['invalid'], email: [] })
      expect(helper.form_state_classes(model, :name)).to include('rose-500')
      expect(helper.form_state_classes(model, :email)).to include('slate-200')
    end
  end

  describe '#sidebar_link_classes' do
    it 'styles active links and inactive submenus differently' do
      allow(helper).to receive(:controller_name).and_return('suppliers')
      expect(helper.sidebar_link_classes(:suppliers)).to include('font-semibold')
      expect(helper.sidebar_link_classes(:clients, variant: :submenu)).to include('text-slate-500')
      expect(helper.sidebar_link_classes(:clients)).to include('text-slate-600')
    end
  end

  describe '#error_message_for' do
    it 'returns a blank result for a missing model' do
      expect(helper.error_message_for(nil, :name)).to eq('')
    end

    it 'returns a blank result if the attribute has no errors' do
      expect(helper.error_message_for(double(errors: { name: [] }), :name)).to eq('')
    end
  end
end
