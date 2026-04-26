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

ActiveRecord::Schema[8.1].define(version: 2026_04_26_180313) do
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
    t.check_constraint "person_type::text = ANY (ARRAY['F'::character varying, 'M'::character varying]::text[])"
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
    t.check_constraint "code::text = ANY (ARRAY['PUE'::character varying, 'PPD'::character varying]::text[])", name: "chk_sat_payment_method_types_code"
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
    t.check_constraint "(applies_to::text = ANY (ARRAY['product'::character varying, 'service'::character varying, 'both'::character varying]::text[])) OR applies_to IS NULL"
    t.check_constraint "factor_type::text = ANY (ARRAY['rate'::character varying, 'quota'::character varying, 'exempt'::character varying]::text[])"
    t.check_constraint "tax_type::text = 'transfer'::text AND is_transferrable = true OR tax_type::text = 'withheld'::text AND is_retainable = true"
    t.check_constraint "tax_type::text = ANY (ARRAY['transfer'::character varying, 'withheld'::character varying]::text[])"
    t.check_constraint "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from"
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
    t.check_constraint "role_type::text = ANY (ARRAY['system'::character varying, 'branch'::character varying]::text[])", name: "check_system_roles_role_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'deprecated'::character varying]::text[])", name: "check_system_roles_status"
  end
end
