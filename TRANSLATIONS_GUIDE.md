# Translations Database Setup Guide

## Overview

This application uses a hybrid approach for translations:
- **Database**: Store translations in `translates` table for easy management
- **Fallback**: Use YAML files (`config/locales/*.yml`) when database is unavailable
- **Paranoia**: Soft deletes with paranoia gem for audit trail

## Quick Start

### 1. Run Database Migration

```bash
bundle exec rails db:migrate
```

This creates the `translates` table with:
- `key` - Translation key (e.g., "devise.sessions.new.title")
- `value` - Translation text
- `locale` - Language code (en, es, ko)
- `deleted_at` - Paranoia soft delete timestamp
- Indexes for optimal query performance

### 2. Load Translations from YAML Files

Option A: Using setup script (recommended)
```bash
bin/setup-translations.sh
```

Option B: Using rake task
```bash
rake translations:load
```

Option C: Using Rails seed
```bash
bundle exec rails db:seed
```

This will:
1. Parse all YAML files from `config/locales/`
2. Flatten nested structure into dotted notation
3. Insert translations into database
4. Skip `devise.security_extension` files

## Database Schema

### Table: `translates`

| Column | Type | Description |
|--------|------|-------------|
| id | bigint PK | Primary key |
| key | string(255) | Translation key |
| value | text | Translation content |
| locale | string(10) | Language code |
| deleted_at | datetime | Paranoia soft delete |
| created_at | datetime | Creation timestamp |
| updated_at | datetime | Update timestamp |

### Indexes

- Unique composite on `(key, locale)` WHERE `deleted_at IS NULL`
- Index on `key`
- Index on `locale`
- Index on `deleted_at`

## Usage

### Model Methods

```ruby
# Find a specific translation
translate = Translate.find_by_key_and_locale('devise.sessions.new.title', 'es')
# => "Punto de Venta"

# Get value with fallback
Translate.value_for('devise.sessions.new.title', 'es', 'Default')
# => "Punto de Venta"

# Query by locale
Translate.by_locale('ko').count
# => 145

# Query by key
Translate.by_key('devise.sessions.new.title')
# => all translations for this key
```

### Soft Delete Operations

```ruby
# Soft delete (record hidden by default)
translate = Translate.find(1)
translate.destroy

# Query active records only (default)
Translate.count  # excludes soft-deleted

# Query soft-deleted records
Translate.only_deleted.count

# Restore a soft-deleted record
translate.restore

# Permanently delete (bypass paranoia)
translate.really_destroy
```

### Rake Tasks

```bash
# Load YAML files into database
rake translations:load

# Show translation statistics
rake translations:stats

# Restore all soft-deleted translations
rake translations:restore_all

# Permanently remove all soft-deleted translations
rake translations:purge_deleted
```

## I18n Configuration

The application uses a custom I18n backend configured in:
`config/initializers/i18n_database_backend.rb`

### Backend Behavior

1. **On First Request**: Lazy loads all translations from database
2. **Fallback**: If database unavailable, uses YAML files
3. **Error Handling**: Gracefully handles connection failures
4. **Logging**: Rails.logger warns about issues

### Translation Lookup

Rails automatically looks up translations in this order:
1. Database (if table exists and loaded)
2. YAML files (fallback)
3. I18n.default_locale default

### In Views/Controllers

```erb
<!-- Same as before, works with database backend -->
<%= t('.title') %>
<%= t('devise.sessions.new.title') %>
<%= t('devise.failure.user.invalid', default: 'Invalid credentials') %>
```

## Adding New Translations

### Option 1: Add to YAML, then Load

```yaml
# config/locales/en.yml
en:
  custom:
    message: "Hello World"
```

```bash
rake translations:load
```

### Option 2: Add Directly to Database

```ruby
Translate.create!(
  key: 'custom.message',
  value: 'Hello World',
  locale: 'en'
)
```

### Option 3: Update Existing

```ruby
translate = Translate.find_by_key_and_locale('custom.message', 'en')
translate.update(value: 'Hello Universe')
```

## Monitoring

### Check Translation Count

```bash
rake translations:stats
```

Output:
```
📊 Translation Statistics
========================
Total active:      435
Total soft-deleted: 0
Total all:         435

By locale:
  en: 145
  es: 145
  ko: 145
```

### Verify Loading

```bash
bundle exec rails console
> Translate.by_locale('es').count
=> 145
> Translate.by_key('devise.sessions.new.title').pluck(:locale, :value)
=> [["en", "Access Terminal"], ["es", "Punto de Venta"], ["ko", "접속 터미널"]]
```

## Troubleshooting

### Issue: "relation 'translates' does not exist"

**Cause**: Migration not run yet

**Solution**:
```bash
bundle exec rails db:migrate
```

### Issue: "Translation missing" in browser

**Cause**: Key not loaded into database

**Solution**:
```bash
rake translations:load
```

Or check YAML files have correct key structure:
```ruby
# In config/locales/*.yml
locale:
  devise:
    sessions:
      new:
        title: "..."
```

### Issue: Database backend not loading

**Cause**: Table missing or connection error

**Solution**: Check logs
```bash
tail -f log/development.log | grep -i translation
```

Backend automatically falls back to YAML in case of issues.

## Development Workflow

1. **Create translation in YAML**
   ```yaml
   # config/locales/en.yml
   en:
     custom:
       message: "Hello"
   ```

2. **Load into database**
   ```bash
   rake translations:load
   ```

3. **Use in application**
   ```erb
   <%= t('custom.message') %>
   ```

4. **Update directly in database** (if needed)
   ```ruby
   Translate.find_by_key_and_locale('custom.message', 'en').update(value: 'Hi')
   ```

## Production Considerations

1. **Pre-load translations** on application start
2. **Cache database queries** for performance
3. **Monitor table size** and archive old soft-deleted records
4. **Backup database** regularly
5. **Test fallback** to YAML files

## References

- [Paranoia Documentation](https://github.com/ruanpienaar/paranoia)
- [Rails I18n Documentation](https://guides.rubyonrails.org/i18n.html)
- [ActiveRecord Basics](https://guides.rubyonrails.org/active_record_basics.html)
