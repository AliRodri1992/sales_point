# frozen_string_literal: true

namespace :translations do
  desc "Load all translations from YAML files into database"
  task load: :environment do
    puts "🌱 Loading translations from YAML files..."

    # Load all locale files
    Dir.glob(Rails.root.join('config/locales/*.yml')).each do |file|
      next if file.include?('devise.security_extension')

      filename = File.basename(file)
      case filename
      when 'en.yml', 'devise.en.yml'
        Translate.load_from_file(file, 'en')
        puts "✅ Loaded #{filename} (English)"
      when 'es.yml', 'devise.es.yml'
        Translate.load_from_file(file, 'es')
        puts "✅ Loaded #{filename} (Spanish)"
      when 'ko.yml', 'devise.ko.yml'
        Translate.load_from_file(file, 'ko')
        puts "✅ Loaded #{filename} (Korean)"
      end
    end

    puts "\n📊 Summary:"
    Language.where(status: 'active').each do |language|
      count = language.translates.count
      puts "  #{language.code}: #{count} translations"
    end
  end

  desc "Clear all soft-deleted translations and remove them permanently"
  task purge_deleted: :environment do
    count = Translate.only_deleted.count
    Translate.only_deleted.really_destroy_all
    puts "🗑️  Purged #{count} soft-deleted translations"
  end

  desc "Show translation statistics"
  task stats: :environment do
    total = Translate.count
    active = Translate.count
    deleted = Translate.only_deleted.count

    puts "📊 Translation Statistics"
    puts "========================"
    puts "Total active:      #{active}"
    puts "Total soft-deleted: #{deleted}"
    puts "Total all:         #{total}"
    puts ""
    puts "By language:"
    Language.where(status: 'active').each do |language|
      count = language.translates.count
      puts "  #{language.code}: #{count}"
    end
  end

  desc "Restore all soft-deleted translations"
  task restore_all: :environment do
    count = Translate.only_deleted.count
    Translate.only_deleted.restore
    puts "✅ Restored #{count} soft-deleted translations"
  end
end

