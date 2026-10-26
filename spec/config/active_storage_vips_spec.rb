# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Active Storage Vips integration' do
  it 'loads the Ruby image processor and its native library' do
    require 'vips'

    expect(Vips::Image.black(1, 1).width).to eq(1)
  end

  it 'extracts image dimensions using Active Storage analysis' do
    require 'vips'

    image_data = Vips::Image.black(3, 2).pngsave_buffer
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(image_data), filename: 'vips-test.png', content_type: 'image/png'
    )

    blob.analyze

    expect(blob.metadata).to include('width' => 3, 'height' => 2)
  ensure
    blob&.purge
  end
end
