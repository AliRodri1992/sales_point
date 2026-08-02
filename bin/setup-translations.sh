#!/bin/bash
# Setup translations in database
# This script creates the translates table and loads all translations from YAML files

set -e

echo "🗂️  Setting up translations table..."
echo "=================================="

cd "$(dirname "$0")"

# Run migration
echo "📝 Running migration..."
bundle exec rails db:migrate

# Run seeds
echo "🌱 Loading translations from YAML files..."
bundle exec rails db:seed

echo ""
echo "✅ Translations setup complete!"
echo ""
echo "📊 Summary:"
bundle exec rails runner "
  require 'table_print'
  
  puts 'Total translations by locale:'
  %w[en es ko].each do |locale|
    count = Translate.by_locale(locale).count
    puts \"  #{locale}: #{count} translations\"
  end
  
  puts ''
  puts 'Sample translations:'
  sample = Translate.limit(5)
  sample.each do |t|
    puts \"  [#{t.locale}] #{t.key}: #{t.value.truncate(50)}\"
  end
"
