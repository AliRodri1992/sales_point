# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeltaIconsHelper, type: :helper do
  it 'renders a native, accessible Delta SVG without RailsIcons' do
    result = helper.delta_icon('information-circle', class: 'size-4 text-emerald-600')
    node = Nokogiri::HTML.fragment(result).at_css('svg')

    expect(node).to be_present
    expect(node['viewbox']).to eq('0 0 24 24')
    expect(node['class']).to include('size-4', 'text-emerald-600')
    expect(node['aria-hidden']).to eq('true')
    expect(node.at_css('circle')).to be_present
    expect(node.at_css('path')).to be_present
  end

  it 'draws distinct SVGs for document search and attachments' do
    search = Nokogiri::HTML.fragment(helper.delta_icon('document-magnifying-glass')).at_css('svg')
    attachment = Nokogiri::HTML.fragment(helper.delta_icon('paper-clip')).at_css('svg')
    information = Nokogiri::HTML.fragment(helper.delta_icon('information-circle')).at_css('svg')

    expect(search.at_css('circle')).to be_present
    expect(attachment.css('path').size).to eq(1)
    expect(search.to_html).not_to eq(information.to_html)
    expect(attachment.to_html).not_to eq(information.to_html)
  end

  it 'renders distinct trend icons used by the dashboard' do
    up = Nokogiri::HTML.fragment(helper.delta_icon('arrow-trending-up')).at_css('svg')
    down = Nokogiri::HTML.fragment(helper.delta_icon('arrow-trending-down')).at_css('svg')

    expect(up.at_css('path')['d']).to include('M4 17')
    expect(down.at_css('path')['d']).to include('M4 7')
    expect(up.to_html).not_to eq(down.to_html)
  end

  it 'renders original receipt and chart illustrations used by dashboard KPIs' do
    icons = %w[arrow-trending-up receipt-percent presentation-chart-line banknotes]
    rendered = icons.map do |name|
      Nokogiri::HTML.fragment(helper.delta_icon(name, class: 'size-5')).at_css('svg')
    end

    expect(rendered).to all(be_present)
    expect(rendered.map { |svg| svg.at_css('path, circle, rect') }).to all(be_present)
    expect(rendered.map(&:to_html).uniq.length).to eq(icons.length)
  end

  it 'defines every icon configured by the dashboard KPI cards' do
    source = Rails.root.join('app/views/admin/dashboard/_kpi_grid.html.erb').read
    names = source.scan(/icon_name:\s*['"]([^'"]+)['"]/).flatten

    expect(names).to include('receipt-percent', 'presentation-chart-line')
    expect(names).to all(satisfy do |name|
      key = described_class::ICON_ALIASES.fetch(name, name)
      described_class::ICON_SHAPES.key?(key)
    end)
  end

  it 'rejects an undefined icon rather than showing an unrelated information symbol' do
    expect { helper.delta_icon('not-a-defined-delta-icon') }
      .to raise_error(ArgumentError, /Delta POS SVG icon not defined/)
  end

  it 'supports semantic icon aliases, stimulus attributes, and custom dimensions' do
    result = helper.delta_icon('cog-6-tooth', class: 'size-6', data: { sidebar_icon: 'settings' })
    node = Nokogiri::HTML.fragment(result).at_css('svg')

    expect(node['data-sidebar-icon']).to eq('settings')
    expect(node.at_css('path')).to be_present
  end

  it 'defines an original illustration for every literal icon used in the application' do
    sources = Rails.root.glob('app/{views,components,helpers}/**/*.{erb,rb}')
    names = sources.flat_map do |file|
      file.read.scan(/(?<!\w)delta_icon\(\s*['"]([^'"]+)['"]/).flatten
    end.uniq
    unresolved = names.reject do |name|
      key = described_class::ICON_ALIASES.fetch(name, name)
      described_class::ICON_SHAPES.key?(key)
    end

    expect(unresolved).to be_empty
  end

  it 'calls the view helper explicitly inside ViewComponent templates' do
    components = Rails.root.glob('app/components/**/*.html.erb')
    offenders = components.filter_map do |file|
      source = file.read
      next unless source.match?(/(?<!helpers\.)\bdelta_icon\s*\(?/)

      file.relative_path_from(Rails.root).to_s
    end

    expect(offenders).to be_empty
  end

  it 'resolves all permission module icons rendered through dynamic helper calls' do
    names = SystemRolesHelper::MODULE_ICONS.values.uniq + [SystemRolesHelper::DEFAULT_MODULE_ICON]
    unresolved = names.reject do |name|
      key = described_class::ICON_ALIASES.fetch(name, name)
      described_class::ICON_SHAPES.key?(key)
    end

    expect(unresolved).to be_empty
  end

  it 'never loads obsolete Heroicons template calls' do
    sources = Rails.root.glob('app/{views,components,helpers}/**/*.{erb,rb}')
    violations = sources.filter_map do |file|
      next if file.basename.to_s == 'delta_icons_helper.rb'

      content = file.read
      next unless content.match?(/(?<!\w)icon\(|helpers\.icon\b|(?:RailsIcons|heroicons)/i)

      file.relative_path_from(Rails.root).to_s
    end

    expect(violations).to be_empty
  end
end
