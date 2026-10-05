# frozen_string_literal: true

ICON_BOX_ROUNDED = %i[lg xl xxl full].freeze

RSpec.describe 'UI components', type: :component do
  describe Ui::ButtonComponent do
    it 'renders every supported variant and size' do
      Ui::ButtonComponent::VARIANTS.product(Ui::ButtonComponent::SIZES).each do |variant, size|
        rendered = render_inline(described_class.new(text: 'Action', variant:, size:))

        expect(rendered.to_html).to include('Action')
      end
    end

    it 'renders links and button states' do
      rendered = render_inline(described_class.new(
                                 text: 'Save',
                                 href: '/save',
                                 variant: :success,
                                 size: :lg,
                                 full_width: true,
                                 disabled: true,
                                 icon: :arrow_right,
                                 icon_position: :right
                               ))

      expect(rendered.css('a')).to be_present
      expect(rendered.to_html).to include('Save', 'w-full', 'opacity-50', 'cursor-not-allowed')
    end

    it 'rejects unsupported variants and sizes' do
      expect { described_class.new(text: 'Action', variant: :unknown) }.to raise_error(ArgumentError)
      expect { described_class.new(text: 'Action', size: :unknown) }.to raise_error(ArgumentError)
    end
  end

  describe Ui::BadgeComponent do
    it 'renders all supported colors' do
      Ui::BadgeComponent::COLORS.each do |color|
        rendered = render_inline(described_class.new(text: 'Status', color:))

        expect(rendered.to_html).to include('Status')
      end
    end

    it 'rejects unsupported colors' do
      expect { described_class.new(text: 'Status', color: :unknown) }.to raise_error(ArgumentError)
    end
  end

  describe Ui::IconBoxComponent do
    it 'renders every supported size' do
      Ui::IconBoxComponent::SIZES.each do |size|
        rendered = render_inline(described_class.new(icon: :check, size:))

        expect(rendered.css('div')).to be_present
      end
    end

    it 'renders every supported color and rounded shape' do
      Ui::IconBoxComponent::COLORS.each do |color|
        ICON_BOX_ROUNDED.each do |rounded|
          rendered = render_inline(
            described_class.new(icon: :check, size: :lg, color:, rounded:)
          )

          expect(rendered.css('div')).to be_present
        end
      end
    end
  end

  describe Ui::CardComponent do
    it 'renders all configurable styles' do
      rendered = render_inline(
        described_class.new(
          padding: false,
          border: false,
          shadow: false,
          hover: true,
          full_height: true
        )
      )

      expect(rendered.to_html).to include('hover:-translate-y-1', 'h-full')
    end

    it 'renders optional content slots' do
      rendered = render_inline(described_class.new) do |component|
        component.with_header { 'Header' }
        component.with_body { 'Body' }
        component.with_footer { 'Footer' }
      end

      html = rendered.to_html
      expect(html).to include('Header', 'Body', 'Footer')
    end
  end

  describe Ui::SectionTitleComponent do
    it 'renders optional title content' do
      rendered = render_inline(
        described_class.new(
          title: 'Section',
          subtitle: 'Details',
          badge: 'New'
        )
      )

      expect(rendered.to_html).to include('Section', 'Details', 'New')
    end

    it 'supports non-centered titles' do
      rendered = render_inline(described_class.new(title: 'Section', centered: false))

      expect(rendered.to_html).not_to include('text-center')
    end
  end

  describe Ui::StatisticComponent do
    it 'renders the statistic with and without an icon' do
      plain = render_inline(described_class.new(number: 10, label: 'Sales'))
      with_icon = render_inline(
        described_class.new(number: 20, label: 'Orders', icon: :chart_bar)
      )

      expect(plain.to_html).to include('10', 'Sales')
      expect(with_icon.to_html).to include('20', 'Orders')
    end
  end
end
