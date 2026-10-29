# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SidebarHelper, type: :helper do
  it 'renders a reusable SVG icon with its stable navigation identifier' do
    markup = helper.sidebar_navigation_icon(:dashboard, class_name: 'size-5')
    icon = Nokogiri::HTML.fragment(markup).at_css('svg')

    expect(icon).to be_present
    expect(icon['data-sidebar-icon']).to eq('dashboard')
    expect(icon['aria-hidden']).to eq('true')
    expect(icon['class']).to include('size-5')
  end

  it 'rejects unknown icon identifiers rather than silently showing the wrong symbol' do
    expect { helper.sidebar_navigation_icon(:unknown_module) }.to raise_error(KeyError)
  end
end
