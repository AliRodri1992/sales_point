# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ui::SkeletonComponent, type: :component do
  described_class::VARIANTS.each do |variant|
    it "renders the #{variant} skeleton without interactive or announced controls" do
      rendered = render_inline(described_class.new(variant:, rows: 3, columns: 4))

      expect(rendered.at_css('.delta-skeleton[aria-hidden="true"]')).to be_present
      expect(rendered.css('.delta-skeleton__bar')).not_to be_empty
      expect(rendered.css('button, input, a')).to be_empty
    end
  end

  it 'renders the requested number of table rows and columns' do
    rendered = render_inline(described_class.new(variant: :table, rows: 3, columns: 4))

    expect(rendered.css('.delta-skeleton__table-grid')).to have(4).items
    expect(rendered.css('.delta-skeleton__table-grid:first-child .delta-skeleton__bar')).to have(4).items
  end

  it 'rejects unknown layouts and unreasonable placeholder counts' do
    expect { described_class.new(variant: :unknown) }.to raise_error(ArgumentError)
    expect { described_class.new(variant: :table, rows: 0) }.to raise_error(ArgumentError)
    expect { described_class.new(variant: :table, rows: 13) }.to raise_error(ArgumentError)
    expect { described_class.new(variant: :table, columns: 9) }.to raise_error(ArgumentError)
  end
end
