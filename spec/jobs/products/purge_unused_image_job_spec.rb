# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Products::PurgeUnusedImageJob, type: :job do
  def image_blob(purpose: 'product_image', created_at: 2.days.ago)
    bytes = Rails.root.join('app/assets/images/favicon-32x32.png').binread
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: 'image.png',
                                                  metadata: { purpose: })
    blob.update!(created_at:)
    blob
  end

  it 'removes an abandoned product image after its retention period' do
    blob = image_blob
    described_class.perform_now(blob.id)
    expect(ActiveStorage::Blob.find_by(id: blob.id)).to be_nil
  end

  it 'preserves attached images, recent uploads and blobs from other modules' do
    attached = image_blob
    create(:product).image.attach(attached)
    recent = image_blob(created_at: Time.current)
    other = image_blob(purpose: 'supplier_document')
    [attached, recent, other].each do |blob|
      described_class.perform_now(blob.id)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    end
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
