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
        expect(classes).to include('bg-blue-50', 'font-semibold', 'text-blue-600')
      end

      it 'highlights only the matching item (only one active)' do
        expect(helper.sidebar_link_classes('dashboard')).to include('bg-blue-50')
        expect(helper.sidebar_link_classes('languages')).not_to include('bg-blue-50')
      end

      it 'does not highlight when inactive' do
        classes = helper.sidebar_link_classes('languages')
        expect(classes).to include('text-slate-600', 'hover:bg-slate-50')
        expect(classes).not_to include('bg-blue-50', 'text-blue-600')
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
        ).to include('bg-blue-50', 'font-semibold', 'text-blue-600')
      end

      it 'keeps slate-500 coloring when inactive' do
        classes = helper.sidebar_link_classes('dashboard', variant: :submenu)
        expect(classes).to include('text-slate-500', 'hover:bg-slate-50')
        expect(classes).not_to include('bg-blue-50')
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
end
