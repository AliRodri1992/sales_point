# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier document and schedule concurrency', type: :model, concurrent_db: true do
  self.use_transactional_tests = false

  let!(:organization) { create(:organization) }
  let!(:supplier) { create(:supplier, organization:) }
  let!(:branch) { create(:branch, organization:) }

  def parallel_attempts
    gate = Queue.new
    workers = Array.new(2) do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          yield(index)
        end
      end
    end
    2.times { gate << true }
    workers.map(&:value)
  ensure
    workers&.each { |thread| thread.join if thread.alive? }
  end

  it 'imports a legacy supplier document once when two workers race' do
    supplier.documents.attach(
      io: StringIO.new('%PDF-1.4 supplier document'),
      filename: 'legacy-document.pdf', content_type: 'application/pdf'
    )
    attachment = supplier.documents.attachments.last
    # Simulate an attachment created before supplier document tracking existed.
    SupplierDocument.where(attachment_id: attachment.id).delete_all

    results = parallel_attempts do
      SupplierDocument.import_existing!(Supplier.find(supplier.id))
      :imported
    end
    expect(results).to eq(%i[imported imported])
    expect(SupplierDocument.where(attachment_id: attachment.id).count).to eq(1)
  end

  it 'persists at most one of two overlapping schedule submissions' do
    results = parallel_attempts do |index|
      schedule = SupplierSchedule.new(
        supplier_id: supplier.id, branch_id: branch.id, kind: 'delivery', weekday: 1,
        starts_at: index.zero? ? '09:00' : '10:00', ends_at: '11:00'
      )
      begin
        schedule.save!
        :saved
      rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid
        :rejected
      end
    end
    expect(results.sort).to eq(%i[rejected saved])
    expect(SupplierSchedule.not_deleted.where(supplier:, branch:, kind: 'delivery', weekday: 1).count).to eq(1)
  end
end
