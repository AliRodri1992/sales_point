# frozen_string_literal: true

namespace :suppliers do
  namespace :documents do
    desc 'Idempotently import legacy supplier attachments into versioned document records'
    task backfill: :environment do
      Supplier.find_each do |supplier|
        SupplierDocument.import_existing!(supplier)
      end
      puts 'Supplier document backfill complete'
    end
  end
end
