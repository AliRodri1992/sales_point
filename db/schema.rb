# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_18_011718) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.string "city", limit: 100
    t.string "country", limit: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "exterior_number", limit: 20
    t.string "geocoding_status", limit: 20, default: "pending", null: false
    t.string "interior_number", limit: 20
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "neighborhood", limit: 100
    t.string "postal_code", limit: 10, null: false
    t.string "state", limit: 100
    t.string "street", limit: 150
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_addresses_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["geocoding_status"], name: "index_addresses_on_geocoding_status"
    t.index ["postal_code", "country", "geocoding_status"], name: "idx_on_postal_code_country_geocoding_status_2c6ededc92"
    t.index ["postal_code"], name: "index_addresses_on_postal_code"
    t.check_constraint "latitude >= '-90'::integer::numeric AND latitude <= 90::numeric OR latitude IS NULL", name: "check_latitude_range"
    t.check_constraint "longitude >= '-180'::integer::numeric AND longitude <= 180::numeric OR longitude IS NULL", name: "check_longitude_range"
  end

  create_table "branches", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "name"
    t.string "phone"
    t.boolean "status"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_branches_on_deleted_at"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "name"
    t.boolean "status"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_categories_on_deleted_at"
  end

  create_table "demo_requests", force: :cascade do |t|
    t.string "company", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", null: false
    t.text "message"
    t.string "name", null: false
    t.string "phone"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_demo_requests_on_deleted_at"
    t.index ["email"], name: "index_demo_requests_on_email"
    t.index ["status"], name: "index_demo_requests_on_status"
  end

  create_table "languages", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "flag_iso"
    t.string "name"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_languages_on_deleted_at"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "sat_banks", primary_key: "code", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "name", limit: 255, null: false
    t.boolean "status", default: true, null: false
    t.datetime "updated_at", null: false
    t.datetime "valid_from", precision: nil
    t.datetime "valid_to", precision: nil
    t.index ["code"], name: "index_sat_banks_on_code", where: "((deleted_at IS NULL) AND (status = true))"
    t.index ["deleted_at"], name: "index_sat_banks_on_deleted_at"
    t.index ["name"], name: "index_sat_banks_on_name"
    t.index ["valid_from", "valid_to"], name: "index_sat_banks_on_valid_from_and_valid_to", where: "(deleted_at IS NULL)"
    t.check_constraint "code::text = TRIM(BOTH FROM code)", name: "chk_sat_banks_code_trim"
    t.check_constraint "code::text ~ '^[0-9]{3}$'::text", name: "chk_sat_banks_code_format"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from", name: "chk_sat_banks_validity"
  end

  create_table "sat_currencies", force: :cascade do |t|
    t.string "code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.integer "decimals", default: 2, null: false
    t.datetime "deleted_at", precision: nil
    t.string "description", limit: 100, null: false
    t.string "symbol", limit: 5
    t.datetime "updated_at", null: false
    t.decimal "variation_percentage", precision: 5, scale: 2
    t.index ["code"], name: "index_sat_currencies_on_code", unique: true
    t.index ["deleted_at"], name: "index_sat_currencies_on_deleted_at"
    t.check_constraint "code::text = upper(TRIM(BOTH FROM code))", name: "chk_sat_currencies_code_uppercase"
    t.check_constraint "code::text ~ '^[A-Z]{3}$'::text", name: "chk_sat_currencies_code_format"
    t.check_constraint "decimals = ANY (ARRAY[0, 2, 3, 4, 5, 6, 8])", name: "chk_sat_currencies_decimals_allowed"
    t.check_constraint "decimals >= 0 AND decimals <= 6", name: "chk_sat_currencies_decimals_range"
    t.check_constraint "variation_percentage >= 0::numeric OR variation_percentage IS NULL", name: "chk_sat_currencies_variation_positive"
  end

  create_table "sat_fiscal_regimes", force: :cascade do |t|
    t.string "code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description", limit: 255, null: false
    t.string "person_type", limit: 1, null: false
    t.datetime "updated_at", null: false
    t.date "valid_from"
    t.date "valid_to"
    t.index ["code", "valid_from"], name: "index_sat_fiscal_regimes_on_code_and_valid_from", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_sat_fiscal_regimes_on_deleted_at"
    t.index ["person_type"], name: "index_sat_fiscal_regimes_on_person_type", where: "(deleted_at IS NULL)"
    t.index ["valid_from", "valid_to"], name: "index_sat_fiscal_regimes_on_valid_from_and_valid_to", where: "(deleted_at IS NULL)"
    t.check_constraint "person_type::text = ANY (ARRAY['F'::character varying::text, 'M'::character varying::text])"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from"
  end

  create_table "sat_months", primary_key: "code", id: { type: :string, limit: 2 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description", limit: 50, null: false
    t.integer "month_number", null: false
    t.boolean "status", default: true, null: false
    t.datetime "updated_at", null: false
    t.date "valid_from"
    t.date "valid_to"
    t.index ["code"], name: "index_sat_months_on_code", where: "((deleted_at IS NULL) AND (status = true))"
    t.index ["deleted_at"], name: "index_sat_months_on_deleted_at"
    t.index ["month_number"], name: "index_sat_months_on_month_number", where: "(deleted_at IS NULL)"
    t.index ["status"], name: "index_sat_months_on_status"
    t.index ["valid_from", "valid_to"], name: "index_sat_months_on_valid_from_and_valid_to", where: "(deleted_at IS NULL)"
    t.check_constraint "code::integer = month_number"
    t.check_constraint "code::text ~ '^(0[1-9]|1[0-2])$'::text"
    t.check_constraint "month_number >= 1 AND month_number <= 12"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from"
  end

  create_table "sat_payment_method_types", force: :cascade do |t|
    t.string "code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description", limit: 100, null: false
    t.boolean "status", default: true, null: false
    t.datetime "updated_at", null: false
    t.date "valid_from"
    t.date "valid_to"
    t.index ["code"], name: "index_sat_payment_method_types_on_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_sat_payment_method_types_on_deleted_at"
    t.index ["status"], name: "index_sat_payment_method_types_on_status"
    t.index ["valid_from", "valid_to"], name: "index_sat_payment_method_types_on_valid_from_and_valid_to", where: "(deleted_at IS NULL)"
    t.check_constraint "code::text = ANY (ARRAY['PUE'::character varying::text, 'PPD'::character varying::text])", name: "chk_sat_payment_method_types_code"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from", name: "chk_sat_payment_method_types_validity"
  end

  create_table "sat_payment_methods", force: :cascade do |t|
    t.string "code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description", limit: 255, null: false
    t.boolean "status", default: true, null: false
    t.datetime "updated_at", null: false
    t.datetime "valid_from", precision: nil
    t.datetime "valid_to", precision: nil
    t.index ["code"], name: "index_sat_payment_methods_active", where: "((deleted_at IS NULL) AND (status = true))"
    t.index ["code"], name: "index_sat_payment_methods_unique", unique: true, where: "((deleted_at IS NULL) AND (status = true))"
    t.index ["deleted_at"], name: "index_sat_payment_methods_on_deleted_at"
    t.index ["description"], name: "index_sat_payment_methods_on_description"
    t.index ["valid_from", "valid_to"], name: "index_sat_payment_methods_on_valid_from_and_valid_to", where: "(deleted_at IS NULL)"
    t.check_constraint "code::text ~ '^[0-9]{2}$'::text", name: "chk_sat_payment_methods_code_format"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from", name: "chk_sat_payment_methods_validity"
  end

  create_table "sat_taxes", force: :cascade do |t|
    t.string "applies_to"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description", limit: 255
    t.string "factor_type", default: "rate", null: false
    t.boolean "is_retainable", default: false
    t.boolean "is_transferrable", default: true
    t.string "name", null: false
    t.integer "priority", default: 1, null: false
    t.boolean "status", default: true
    t.string "tax_type", default: "transfer", null: false
    t.datetime "updated_at", null: false
    t.date "valid_from"
    t.date "valid_to"
    t.index "lower(TRIM(BOTH FROM code))", name: "index_sat_taxes_on_LOWER_TRIM_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["applies_to"], name: "index_sat_taxes_on_applies_to"
    t.index ["factor_type"], name: "index_sat_taxes_on_factor_type"
    t.index ["status", "deleted_at"], name: "index_sat_taxes_on_status_and_deleted_at"
    t.index ["status"], name: "index_sat_taxes_on_status"
    t.index ["tax_type"], name: "index_sat_taxes_on_tax_type"
    t.index ["valid_from", "valid_to"], name: "index_sat_taxes_on_valid_from_and_valid_to", where: "(deleted_at IS NULL)"
    t.check_constraint "(applies_to::text = ANY (ARRAY['product'::character varying::text, 'service'::character varying::text, 'both'::character varying::text])) OR applies_to IS NULL"
    t.check_constraint "factor_type::text = ANY (ARRAY['rate'::character varying::text, 'quota'::character varying::text, 'exempt'::character varying::text])"
    t.check_constraint "tax_type::text = 'transfer'::text AND is_transferrable = true OR tax_type::text = 'withheld'::text AND is_retainable = true"
    t.check_constraint "tax_type::text = ANY (ARRAY['transfer'::character varying::text, 'withheld'::character varying::text])"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from"
  end

  create_table "sat_unit_keys", force: :cascade do |t|
    t.string "code", limit: 5, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description", limit: 255, null: false
    t.string "symbol", limit: 10
    t.datetime "updated_at", null: false
    t.datetime "valid_from", precision: nil
    t.datetime "valid_to", precision: nil
    t.index ["code"], name: "index_sat_unit_keys_on_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_sat_unit_keys_on_deleted_at"
    t.index ["valid_from"], name: "index_sat_unit_keys_on_valid_from"
    t.index ["valid_to"], name: "index_sat_unit_keys_on_valid_to"
    t.check_constraint "code::text = upper(code::text)", name: "chk_sat_unit_keys_upper_code"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from", name: "chk_sat_unit_keys_valid_range"
  end

  create_table "system_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description"
    t.string "name", limit: 50, null: false
    t.string "role_type", limit: 20, null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_system_roles_on_created_at"
    t.index ["deleted_at"], name: "index_system_roles_on_deleted_at"
    t.index ["name", "role_type"], name: "index_system_roles_on_name_and_role_type", unique: true
    t.index ["role_type", "status"], name: "index_system_roles_on_role_type_and_status"
    t.check_constraint "deleted_at IS NULL AND status::text <> 'deprecated'::text OR deleted_at IS NOT NULL", name: "check_system_roles_deleted_status"
    t.check_constraint "role_type::text = ANY (ARRAY['system'::character varying::text, 'branch'::character varying::text])", name: "check_system_roles_role_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'deprecated'::character varying::text])", name: "check_system_roles_status"
  end

  create_table "translates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "key", limit: 255, null: false
    t.string "locale", limit: 10, default: "en", null: false
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["deleted_at"], name: "index_translates_on_deleted_at"
    t.index ["key", "locale"], name: "index_translates_on_key_and_locale", unique: true, where: "(deleted_at IS NULL)"
    t.index ["key"], name: "index_translates_on_key"
    t.index ["locale"], name: "index_translates_on_locale"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "current_session_token"
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.datetime "deleted_at", precision: nil
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.bigint "language_id"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "last_sign_in_ip_country", limit: 2
    t.text "locked_Reason"
    t.datetime "locked_at"
    t.datetime "login_attempts_window_start"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "session_expires_at"
    t.datetime "session_revoked_at"
    t.integer "sign_in_count", default: 0, null: false
    t.string "status", default: "active", null: false
    t.string "theme", limit: 50, default: "theme-material-red", null: false
    t.string "unique_session_id"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "user_type", null: false
    t.string "username"
    t.index "lower((email)::text)", name: "idx_users_email", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email", "status"], name: "index_users_on_email_and_status"
    t.index ["language_id"], name: "index_users_on_language_id", where: "(language_id IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["session_expires_at"], name: "idx_users_session_active", where: "(session_expires_at IS NOT NULL)"
    t.index ["status"], name: "idx_users_active", where: "((status)::text = 'active'::text)"
    t.index ["status"], name: "index_users_on_status"
    t.index ["user_type", "status"], name: "index_users_on_user_type_and_status"
    t.index ["user_type"], name: "index_users_on_user_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'blocked'::character varying::text, 'suspended'::character varying::text, 'deleted'::character varying::text])", name: "chk_users_status"
    t.check_constraint "user_type::text = ANY (ARRAY['employee'::character varying::text, 'customer'::character varying::text, 'supplier'::character varying::text])", name: "chk_users_user_type"
  end

  add_foreign_key "users", "languages"
end
