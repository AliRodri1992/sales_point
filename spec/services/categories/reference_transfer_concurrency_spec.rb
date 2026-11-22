# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe 'Category reference transfer concurrency', :concurrent_db do
  it 'allows a normal product edit to finish while reassignment waits for that product' do
    organization = create(:organization)
    source = create(:category, organization:)
    target = create(:category, organization:)
    product = create(:product, organization:, category: source)
    actor = create(:user)
    editor_ready = Queue.new
    resume_editor = Queue.new
    transfer_pid = Queue.new
    results = Queue.new
    workers = []

    workers << Thread.new do
      ApplicationRecord.connection_pool.with_connection do
        Product.transaction do
          locked = Product.lock.find(product.id)
          editor_ready << true
          resume_editor.pop
          writer = Products::SaveCatalogEntry.new(product: locked, actor:, attributes: { category_id: target.id })
          results << writer.call.present?
        end
      end
    rescue StandardError => e
      results << e.class.name
    end
    Timeout.timeout(10) { editor_ready.pop }

    workers << Thread.new do
      ApplicationRecord.connection_pool.with_connection do |connection|
        transfer_pid << connection.select_value('SELECT pg_backend_pid()')
        transfer = Categories::ReferenceTransfer.new(source: Category.find(source.id), target_category_id: target.id)
        results << transfer.save
      end
    rescue StandardError => e
      results << e.class.name
    end
    pid = Timeout.timeout(10) { transfer_pid.pop }
    Timeout.timeout(10) do
      loop do
        sql = "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(pid)}"
        wait = ApplicationRecord.connection.select_value(sql)
        break if wait == 'Lock'

        sleep 0.02
      end
    end
    resume_editor << true
    Timeout.timeout(10) { workers.each(&:join) }

    expect(Array.new(2) { results.pop }).to contain_exactly(true, true)
    expect(product.reload.category_id).to eq(target.id)
    expect(source.reload.in_use?).to be(false)
  ensure
    resume_editor&.push(true)
    workers&.each { |worker| worker.join(5) || worker.kill }
  end
end
