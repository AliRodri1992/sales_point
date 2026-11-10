# frozen_string_literal: true

namespace :translations do
  desc 'Import missing YAML translations (OVERWRITE=1 replaces overrides; DRY_RUN=1 previews)'
  task load: :environment do
    overwrite = ENV['OVERWRITE'] == '1'
    dry_run = ENV['DRY_RUN'] == '1'
    puts '🌱 Loading translations from YAML files...'
    puts "Mode: #{dry_run ? 'DRY RUN' : 'write'}, existing overrides: #{overwrite ? 'replace' : 'preserve'}"

    # Support both module.en.yml and en.module.yml naming conventions.
    Rails.root.glob('config/locales/*.yml').sort.each do |file|
      filename = file.basename.to_s
      next if filename.start_with?('devise.security_extension.')

      locale = filename[/\A(en|es|ko)(?=\.)/, 1] ||
               filename[/\.(en|es|ko)\.yml\z/, 1]
      next unless locale

      Translate.load_from_file(file, locale, overwrite: overwrite, dry_run: dry_run)
      puts "✅ Loaded #{filename} (#{locale})"
    end

    puts "\n📊 Summary:"
    Language.where(status: 'active').find_each do |language|
      count = language.translates.count
      puts "  #{language.code}: #{count} translations"
    end
  end

  desc 'Clear all soft-deleted translations and remove them permanently'
  task purge_deleted: :environment do
    count = Translate.only_deleted.count
    Translate.only_deleted.really_destroy_all
    puts "🗑️  Purged #{count} soft-deleted translations"
  end

  desc 'Show translation statistics'
  task stats: :environment do
    total = Translate.with_deleted.count
    active = Translate.count
    deleted = Translate.only_deleted.count

    puts '📊 Translation Statistics'
    puts '========================'
    puts "Total active:      #{active}"
    puts "Total soft-deleted: #{deleted}"
    puts "Total all:         #{total}"
    puts ''
    puts 'By language:'
    Language.where(status: 'active').find_each do |language|
      count = language.translates.count
      puts "  #{language.code}: #{count}"
    end
  end

  desc 'Restore all soft-deleted translations'
  task restore_all: :environment do
    count = Translate.only_deleted.count
    Translate.only_deleted.restore
    puts "✅ Restored #{count} soft-deleted translations"
  end
end
