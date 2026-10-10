# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ui::IconComponent, type: :component do
  describe '#initialize' do
    it 'accepts supported defaults' do
      expect(described_class.new(name: :home)).to be_a(described_class)
    end

    it 'rejects an unsupported variant' do
      expect { described_class.new(name: :home, variant: :invalid) }
        .to raise_error(ArgumentError, 'Variant inválido')
    end

    it 'rejects an unsupported size' do
      expect { described_class.new(name: :home, size: :gigantic) }
        .to raise_error(ArgumentError, 'Size inválido')
    end

    it 'rejects an unsupported color' do
      expect { described_class.new(name: :home, color: :purple) }
        .to raise_error(ArgumentError, 'Color inválido')
    end
  end

  describe 'rendering' do
    it 'renders a valid icon with the requested classes' do
      rendered = render_inline(described_class.new(
            name: :home,
            size: :lg,
            color: :success,
            css_class: 'custom-icon'
      ))

      expect(rendered.css('svg')).to be_present
      expect(rendered.css('svg').first['class']).to include(
        'h-6', 'w-6', 'text-emerald-600', 'custom-icon'
      )
    end
  end
end
