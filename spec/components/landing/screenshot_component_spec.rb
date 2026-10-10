# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Landing::ScreenshotComponent, type: :component do
  it 'renders the screenshot section content and demo link' do
    render_inline(
      described_class.new(
        title: 'See Delta POS in action',
        description: 'A clearer view of your operation',
        image: 'dashboard-preview.png'
      )
    )

    expect(page).to have_text('See Delta POS in action')
    expect(page).to have_text('A clearer view of your operation')
    expect(page).to have_link(href: new_demo_request_path)
  end
end
