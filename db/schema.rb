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

ActiveRecord::Schema[8.1].define(version: 2026_10_18_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_payables", force: :cascade do |t|
    t.decimal "amount", precision: 18, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.date "due_on", null: false
    t.bigint "organization_id", null: false
    t.bigint "supplier_id", null: false
    t.bigint "supplier_invoice_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "due_on"], name: "index_account_payables_on_organization_id_and_due_on"
    t.index ["organization_id"], name: "index_account_payables_on_organization_id"
    t.index ["supplier_id"], name: "index_account_payables_on_supplier_id"
    t.index ["supplier_invoice_id"], name: "index_account_payables_on_supplier_invoice_id", unique: true
    t.check_constraint "amount >= 0::numeric", name: "chk_account_payable_amount"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.bigint "addressable_id", null: false
    t.string "addressable_type", null: false
    t.string "city", limit: 100
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "exterior_number", limit: 20
    t.string "geocoding_status", limit: 20, default: "pending", null: false
    t.string "interior_number", limit: 20
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "neighborhood", limit: 100
    t.string "postal_code", limit: 10, null: false
    t.boolean "primary", default: false, null: false
    t.string "purpose", limit: 30, default: "general", null: false
    t.string "reference_notes", limit: 200
    t.string "state", limit: 100
    t.string "street", limit: 150
    t.datetime "updated_at", null: false
    t.index ["addressable_type", "addressable_id", "purpose"], name: "idx_addresses_one_primary_per_purpose", unique: true, where: "((deleted_at IS NULL) AND (\"primary\" = true))"
    t.index ["addressable_type", "addressable_id"], name: "idx_addresses_owner_active", where: "(deleted_at IS NULL)"
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
    t.index ["country_id"], name: "index_addresses_on_country_id"
    t.index ["deleted_at"], name: "index_addresses_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["geocoding_status"], name: "index_addresses_on_geocoding_status"
    t.index ["postal_code", "country_id", "geocoding_status"], name: "idx_on_postal_code_country_id_geocoding_status_73eb116dd6"
    t.index ["postal_code"], name: "index_addresses_on_postal_code"
    t.check_constraint "latitude >= '-90'::integer::numeric AND latitude <= 90::numeric OR latitude IS NULL", name: "check_latitude_range"
    t.check_constraint "longitude >= '-180'::integer::numeric AND longitude <= 180::numeric OR longitude IS NULL", name: "check_longitude_range"
    t.check_constraint "purpose::text = ANY (ARRAY['general'::character varying, 'fiscal'::character varying, 'commercial'::character varying, 'delivery'::character varying]::text[])", name: "chk_addresses_purpose"
  end

  create_table "branches", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "name"
    t.bigint "organization_id"
    t.string "phone"
    t.boolean "status"
    t.datetime "updated_at", null: false
    t.index "organization_id, lower((name)::text)", name: "idx_branches_org_name_active", unique: true, where: "((organization_id IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["deleted_at"], name: "index_branches_on_deleted_at"
    t.index ["organization_id"], name: "index_branches_on_organization_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "name"
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_categories_on_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_categories_on_deleted_at"
    t.index ["name"], name: "index_categories_on_name", where: "(deleted_at IS NULL)"
  end

  create_table "clients", force: :cascade do |t|
    t.string "code", limit: 30, null: false
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "deleted_at", precision: nil
    t.string "email", limit: 150
    t.string "name", limit: 150, null: false
    t.text "notes"
    t.string "phone", limit: 30
    t.string "postal_code", limit: 5
    t.string "rfc", limit: 13
    t.bigint "sat_fiscal_regime_id"
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_clients_on_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_clients_on_deleted_at"
    t.index ["email"], name: "index_clients_on_email"
    t.index ["phone"], name: "index_clients_on_phone"
    t.index ["rfc"], name: "index_clients_on_rfc", unique: true, where: "((rfc IS NOT NULL) AND ((rfc)::text <> ''::text) AND (deleted_at IS NULL))"
    t.index ["sat_fiscal_regime_id"], name: "index_clients_on_sat_fiscal_regime_id"
    t.index ["status"], name: "index_clients_on_status"
    t.check_constraint "code::text = btrim(code::text) AND code::text <> ''::text AND code::text ~ '^[A-Za-z0-9_-]+$'::text", name: "chk_clients_code_format"
    t.check_constraint "credit_limit >= 0::numeric", name: "chk_clients_credit_limit_non_negative"
    t.check_constraint "name::text = btrim(name::text) AND name::text <> ''::text", name: "chk_clients_name_format"
    t.check_constraint "postal_code IS NULL OR postal_code::text = ''::text OR postal_code::text ~ '^[0-9]{5}$'::text", name: "chk_clients_postal_code_format"
    t.check_constraint "rfc IS NULL OR rfc::text = ''::text OR rfc::text ~ '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'::text", name: "chk_clients_rfc_format"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "chk_clients_status"
  end

  create_table "contacts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "contactable_id", null: false
    t.string "contactable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "email", limit: 150
    t.string "mobile_phone", limit: 30
    t.string "name", limit: 150, null: false
    t.text "notes"
    t.string "phone", limit: 30
    t.string "position", limit: 100
    t.boolean "primary", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["contactable_type", "contactable_id", "name"], name: "idx_contacts_owner_active_name", where: "((deleted_at IS NULL) AND (active = true))"
    t.index ["contactable_type", "contactable_id"], name: "idx_contacts_one_active_primary", unique: true, where: "((deleted_at IS NULL) AND (active = true) AND (\"primary\" = true))"
    t.index ["contactable_type", "contactable_id"], name: "index_contacts_on_contactable"
    t.index ["deleted_at"], name: "index_contacts_on_deleted_at"
    t.check_constraint "btrim(name::text) <> ''::text", name: "chk_contacts_name_present"
  end

  create_table "conversation_participants", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conversation_id", "user_id"], name: "idx_conv_participants_unique_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["conversation_id"], name: "index_conversation_participants_on_conversation_id"
    t.index ["deleted_at"], name: "index_conversation_participants_on_deleted_at"
    t.index ["user_id"], name: "index_conversation_participants_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "conversation_type", default: "direct", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.datetime "updated_at", null: false
    t.index ["conversation_type", "deleted_at"], name: "index_conversations_on_conversation_type_and_deleted_at"
    t.index ["deleted_at"], name: "index_conversations_on_deleted_at"
  end

  create_table "countries", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "iso_alpha2", limit: 2, null: false
    t.string "iso_alpha3", limit: 3, null: false
    t.string "iso_numeric", limit: 3, null: false
    t.string "name", limit: 150, null: false
    t.string "phone_code", limit: 10
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_countries_on_active_and_position"
    t.index ["deleted_at"], name: "index_countries_on_deleted_at"
    t.index ["iso_alpha2"], name: "index_countries_on_iso_alpha2", unique: true
    t.index ["iso_alpha3"], name: "index_countries_on_iso_alpha3", unique: true
    t.index ["iso_numeric"], name: "index_countries_on_iso_numeric", unique: true
    t.check_constraint "\"position\" >= 0", name: "chk_countries_position"
    t.check_constraint "iso_alpha2::text ~ '^[A-Z]{2}$'::text", name: "chk_countries_iso_alpha2"
    t.check_constraint "iso_alpha3::text ~ '^[A-Z]{3}$'::text", name: "chk_countries_iso_alpha3"
    t.check_constraint "iso_numeric::text ~ '^[0-9]{3}$'::text", name: "chk_countries_iso_numeric"
  end

  create_table "country_currencies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at", precision: nil
    t.boolean "is_primary", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["country_id", "currency_id"], name: "idx_country_currencies_unique", unique: true
    t.index ["country_id"], name: "idx_country_currencies_one_primary", unique: true, where: "(is_primary = true)"
    t.index ["country_id"], name: "index_country_currencies_on_country_id"
    t.index ["currency_id"], name: "index_country_currencies_on_currency_id"
    t.index ["deleted_at"], name: "index_country_currencies_on_deleted_at"
    t.check_constraint "NOT is_primary OR active", name: "chk_country_currencies_primary_active"
  end

  create_table "currencies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.integer "decimal_places", default: 2, null: false
    t.datetime "deleted_at", precision: nil
    t.string "name", limit: 150, null: false
    t.string "numeric_code", limit: 3
    t.string "symbol", limit: 12
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_currencies_on_active"
    t.index ["code"], name: "index_currencies_on_code", unique: true
    t.index ["deleted_at"], name: "index_currencies_on_deleted_at"
    t.index ["numeric_code"], name: "index_currencies_on_numeric_code", unique: true
    t.check_constraint "code::text ~ '^[A-Z]{3}$'::text", name: "chk_currencies_code"
    t.check_constraint "decimal_places >= 0 AND decimal_places <= 8", name: "chk_currencies_decimal_places"
    t.check_constraint "numeric_code IS NULL OR numeric_code::text ~ '^[0-9]{3}$'::text", name: "chk_currencies_numeric_code"
  end

  create_table "dashboard_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "grid_type", null: false
    t.integer "height", default: 1, null: false
    t.integer "position_x", default: 0, null: false
    t.integer "position_y", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "widget_id", null: false
    t.integer "width", default: 1, null: false
    t.index ["deleted_at"], name: "index_dashboard_preferences_on_deleted_at"
    t.index ["user_id", "widget_id"], name: "index_dashboard_preferences_on_user_id_and_widget_id", unique: true
    t.index ["user_id"], name: "index_dashboard_preferences_on_user_id"
  end

  create_table "demo_request_activities", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "demo_request_id", null: false
    t.text "details"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["action"], name: "index_demo_request_activities_on_action"
    t.index ["deleted_at"], name: "index_demo_request_activities_on_deleted_at"
    t.index ["demo_request_id"], name: "index_demo_request_activities_on_demo_request_id"
    t.index ["user_id"], name: "index_demo_request_activities_on_user_id"
  end

  create_table "demo_requests", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.integer "branches", default: 1, null: false
    t.string "business_type", limit: 30
    t.string "company", null: false
    t.string "contact_channel", limit: 30
    t.string "contact_outcome", limit: 40
    t.datetime "contacted_at"
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "demo_outcome", limit: 40
    t.string "email", null: false
    t.string "locale", default: "es", null: false
    t.text "message"
    t.string "name", null: false
    t.string "next_action", limit: 120
    t.datetime "next_follow_up_at"
    t.string "phone"
    t.datetime "reminder_1h_sent_at"
    t.datetime "reminder_24h_sent_at"
    t.datetime "scheduled_at"
    t.string "status", default: "pending", null: false
    t.boolean "terms_accepted", default: false, null: false
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id", "next_follow_up_at"], name: "idx_demo_requests_assignee_follow_up_active", where: "((deleted_at IS NULL) AND (next_follow_up_at IS NOT NULL))"
    t.index ["assigned_to_id"], name: "index_demo_requests_on_assigned_to_id"
    t.index ["branches"], name: "index_demo_requests_on_branches"
    t.index ["business_type"], name: "index_demo_requests_on_business_type"
    t.index ["contact_outcome"], name: "index_demo_requests_on_contact_outcome"
    t.index ["deleted_at"], name: "index_demo_requests_on_deleted_at"
    t.index ["demo_outcome"], name: "index_demo_requests_on_demo_outcome"
    t.index ["email"], name: "index_demo_requests_on_email"
    t.index ["next_follow_up_at"], name: "index_demo_requests_on_next_follow_up_at"
    t.index ["status", "created_at"], name: "idx_demo_requests_status_created_active", where: "(deleted_at IS NULL)"
    t.index ["status"], name: "index_demo_requests_on_status"
    t.index ["terms_accepted"], name: "index_demo_requests_on_terms_accepted"
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "email", null: false
    t.string "first_name", limit: 80, null: false
    t.string "last_name", limit: 120, null: false
    t.bigint "organization_id", null: false
    t.string "phone", limit: 30
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index "organization_id, lower((email)::text)", name: "idx_employees_org_email_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_employees_on_deleted_at"
    t.index ["organization_id"], name: "index_employees_on_organization_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'terminated'::character varying]::text[])", name: "check_employees_status"
  end

  create_table "financial_audit_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "details", default: {}, null: false
    t.string "event", limit: 80, null: false
    t.bigint "organization_id", null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", limit: 80, null: false
    t.index ["actor_id"], name: "index_financial_audit_events_on_actor_id"
    t.index ["organization_id", "created_at"], name: "index_financial_audit_events_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_financial_audit_events_on_organization_id"
    t.index ["subject_type", "subject_id"], name: "index_financial_audit_events_on_subject_type_and_subject_id"
  end

  create_table "financial_reminder_deliveries", force: :cascade do |t|
    t.bigint "account_payable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "event_key", limit: 64, null: false
    t.bigint "organization_id", null: false
    t.bigint "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_payable_id"], name: "index_financial_reminder_deliveries_on_account_payable_id"
    t.index ["event_key"], name: "index_financial_reminder_deliveries_on_event_key", unique: true
    t.index ["organization_id"], name: "index_financial_reminder_deliveries_on_organization_id"
    t.index ["recipient_id"], name: "index_financial_reminder_deliveries_on_recipient_id"
  end

  create_table "goods_receipt_items", force: :cascade do |t|
    t.decimal "accepted_quantity", precision: 14, scale: 3, null: false
    t.datetime "created_at", null: false
    t.decimal "damaged_quantity", precision: 14, scale: 3, default: "0.0", null: false
    t.datetime "deleted_at"
    t.decimal "delivered_quantity", precision: 14, scale: 3, null: false
    t.date "expires_on"
    t.bigint "goods_receipt_id", null: false
    t.decimal "landed_unit_cost", precision: 18, scale: 6, default: "0.0", null: false
    t.string "lot_code", limit: 100
    t.text "notes"
    t.bigint "purchase_order_item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_receipt_id"], name: "index_goods_receipt_items_on_goods_receipt_id"
    t.index ["purchase_order_item_id"], name: "index_goods_receipt_items_on_purchase_order_item_id"
    t.check_constraint "delivered_quantity >= 0::numeric AND accepted_quantity >= 0::numeric AND damaged_quantity >= 0::numeric AND (accepted_quantity + damaged_quantity) <= delivered_quantity", name: "chk_receipt_item_differences"
  end

  create_table "goods_receipts", force: :cascade do |t|
    t.decimal "actual_freight_amount", precision: 14, scale: 4
    t.decimal "actual_insurance_amount", precision: 14, scale: 4
    t.decimal "additional_discount_amount", precision: 14, scale: 4, default: "0.0", null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.decimal "extra_expenses_amount", precision: 14, scale: 4, default: "0.0", null: false
    t.string "idempotency_key", limit: 100, null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.string "payload_digest", limit: 64
    t.bigint "purchase_order_id", null: false
    t.datetime "received_at", null: false
    t.bigint "received_by_id", null: false
    t.string "status", default: "posted", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_goods_receipts_on_branch_id"
    t.index ["organization_id", "idempotency_key"], name: "idx_goods_receipts_idempotent", unique: true
    t.index ["organization_id"], name: "index_goods_receipts_on_organization_id"
    t.index ["purchase_order_id"], name: "index_goods_receipts_on_purchase_order_id"
    t.index ["received_by_id"], name: "index_goods_receipts_on_received_by_id"
    t.check_constraint "(actual_freight_amount IS NULL OR actual_freight_amount >= 0::numeric) AND (actual_insurance_amount IS NULL OR actual_insurance_amount >= 0::numeric) AND extra_expenses_amount >= 0::numeric AND additional_discount_amount >= 0::numeric", name: "chk_goods_receipts_actual_costs"
  end

  create_table "inventories", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.decimal "max_stock", precision: 14, scale: 3
    t.decimal "min_stock", precision: 14, scale: 3, default: "0.0", null: false
    t.bigint "organization_id", null: false
    t.bigint "product_id", null: false
    t.decimal "stock", precision: 14, scale: 3, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "product_id"], name: "index_inventories_on_branch_id_and_product_id", unique: true
    t.index ["branch_id"], name: "index_inventories_on_branch_id"
    t.index ["organization_id"], name: "index_inventories_on_organization_id"
    t.index ["product_id"], name: "index_inventories_on_product_id"
    t.check_constraint "max_stock IS NULL OR max_stock >= min_stock", name: "chk_inventory_limits"
    t.check_constraint "stock >= 0::numeric AND min_stock >= 0::numeric", name: "chk_inventory_nonnegative"
  end

  create_table "inventory_lots", force: :cascade do |t|
    t.string "code", limit: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.date "expires_on"
    t.bigint "goods_receipt_item_id"
    t.bigint "inventory_id", null: false
    t.bigint "organization_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, default: "0.0", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_receipt_item_id"], name: "index_inventory_lots_on_goods_receipt_item_id"
    t.index ["inventory_id", "code"], name: "index_inventory_lots_on_inventory_id_and_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["inventory_id"], name: "index_inventory_lots_on_inventory_id"
    t.index ["organization_id"], name: "index_inventory_lots_on_organization_id"
    t.check_constraint "quantity >= 0::numeric", name: "chk_inventory_lot_quantity"
  end

  create_table "inventory_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "inventory_id", null: false
    t.bigint "inventory_lot_id"
    t.string "kind", limit: 24, null: false
    t.bigint "organization_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.string "reference", limit: 100
    t.bigint "source_id"
    t.string "source_type"
    t.decimal "stock_after", precision: 14, scale: 3, null: false
    t.decimal "stock_before", precision: 14, scale: 3, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["inventory_id", "created_at"], name: "index_inventory_movements_on_inventory_id_and_created_at"
    t.index ["inventory_id"], name: "index_inventory_movements_on_inventory_id"
    t.index ["inventory_lot_id"], name: "index_inventory_movements_on_inventory_lot_id"
    t.index ["organization_id"], name: "index_inventory_movements_on_organization_id"
    t.index ["source_type", "source_id"], name: "index_inventory_movements_on_source"
    t.index ["user_id"], name: "index_inventory_movements_on_user_id"
    t.check_constraint "quantity <> 0::numeric", name: "chk_movement_nonzero"
  end

  create_table "inventory_serials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "inventory_lot_id", null: false
    t.bigint "organization_id", null: false
    t.string "serial_number", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_lot_id"], name: "index_inventory_serials_on_inventory_lot_id"
    t.index ["organization_id", "serial_number"], name: "idx_inventory_serials_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_inventory_serials_on_organization_id"
  end

  create_table "languages", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "flag_iso"
    t.string "name"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_languages_on_deleted_at"
    t.index ["name"], name: "index_languages_on_name", where: "(deleted_at IS NULL)"
  end

  create_table "membership_features", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "value_type", default: "boolean", null: false
    t.index ["active", "position"], name: "index_membership_features_on_active_and_position"
    t.index ["deleted_at"], name: "index_membership_features_on_deleted_at"
    t.index ["key"], name: "index_membership_features_on_key", unique: true
    t.check_constraint "value_type::text = ANY (ARRAY['boolean'::character varying, 'integer'::character varying, 'decimal'::character varying, 'text'::character varying]::text[])", name: "chk_membership_features_value_type"
  end

  create_table "membership_plan_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.boolean "enabled", default: true, null: false
    t.integer "limit"
    t.bigint "membership_feature_id", null: false
    t.bigint "membership_plan_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["deleted_at"], name: "index_membership_plan_features_on_deleted_at"
    t.index ["membership_feature_id"], name: "index_membership_plan_features_on_membership_feature_id"
    t.index ["membership_plan_id", "membership_feature_id"], name: "idx_membership_plan_features_unique_pair", unique: true
    t.index ["membership_plan_id"], name: "index_membership_plan_features_on_membership_plan_id"
    t.check_constraint "\"limit\" IS NULL OR \"limit\" >= 0", name: "chk_membership_plan_features_limit_non_negative"
  end

  create_table "membership_plans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "billing_interval", default: "monthly", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "MXN", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.decimal "price", precision: 12, scale: 2, default: "0.0", null: false
    t.string "slug", null: false
    t.integer "trial_days", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_membership_plans_on_active_and_position"
    t.index ["deleted_at"], name: "index_membership_plans_on_deleted_at"
    t.index ["slug"], name: "index_membership_plans_on_slug", unique: true
    t.check_constraint "billing_interval::text = ANY (ARRAY['monthly'::character varying, 'yearly'::character varying]::text[])", name: "chk_membership_plans_billing_interval"
    t.check_constraint "price >= 0::numeric", name: "chk_membership_plans_price_non_negative"
    t.check_constraint "trial_days >= 0", name: "chk_membership_plans_trial_days_non_negative"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["deleted_at"], name: "index_messages_on_deleted_at"
    t.index ["user_id"], name: "index_messages_on_user_id"
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
    t.index ["recipient_type", "recipient_id", "created_at"], name: "idx_noticed_notifications_recipient_recent", order: { created_at: :desc }
    t.index ["recipient_type", "recipient_id", "created_at"], name: "idx_noticed_notifications_unread_recent", order: { created_at: :desc }, where: "(read_at IS NULL)"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "onboarding_audits", force: :cascade do |t|
    t.string "action", limit: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.string "section", limit: 50
    t.integer "step"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["action"], name: "index_onboarding_audits_on_action"
    t.index ["deleted_at"], name: "index_onboarding_audits_on_deleted_at"
    t.index ["organization_id", "created_at"], name: "index_onboarding_audits_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_onboarding_audits_on_organization_id"
    t.index ["user_id", "created_at"], name: "index_onboarding_audits_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_onboarding_audits_on_user_id"
  end

  create_table "organization_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "organization_id", null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_organization_memberships_on_deleted_at"
    t.index ["organization_id", "user_id"], name: "idx_org_memberships_active_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "check_org_memberships_status"
  end

  create_table "organization_migrations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "organization_id", null: false
    t.string "priority", limit: 20, null: false
    t.string "status", limit: 20, default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "volume", limit: 20, null: false
    t.index ["deleted_at"], name: "index_organization_migrations_on_deleted_at"
    t.index ["organization_id"], name: "idx_org_migrations_org_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_organization_migrations_on_organization_id"
    t.check_constraint "priority::text = ANY (ARRAY['catalog'::character varying, 'inventory'::character varying, 'customers'::character varying, 'all'::character varying]::text[])", name: "check_org_migrations_priority"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'in_progress'::character varying, 'completed'::character varying]::text[])", name: "check_org_migrations_status"
    t.check_constraint "volume::text = ANY (ARRAY['under_500'::character varying, '500_5000'::character varying, 'over_5000'::character varying]::text[])", name: "check_org_migrations_volume"
  end

  create_table "organization_settings", force: :cascade do |t|
    t.bigint "base_currency_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "organization_id", null: false
    t.string "payment_method", limit: 20, default: "cash", null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["base_currency_id"], name: "index_organization_settings_on_base_currency_id"
    t.index ["deleted_at"], name: "index_organization_settings_on_deleted_at"
    t.index ["organization_id"], name: "idx_organization_settings_active_org", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_organization_settings_on_organization_id"
    t.check_constraint "payment_method::text = ANY (ARRAY['cash'::character varying, 'card'::character varying, 'qr'::character varying]::text[])", name: "check_organization_settings_payment_method"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "business_sector", limit: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "name", limit: 150, null: false
    t.datetime "onboarding_completed_at"
    t.integer "onboarding_current_step", default: 1, null: false
    t.jsonb "onboarding_sections", default: {}, null: false
    t.string "onboarding_status", limit: 20, default: "pending", null: false
    t.string "status", limit: 20, default: "active", null: false
    t.string "tax_id", limit: 13, null: false
    t.datetime "updated_at", null: false
    t.index "lower((tax_id)::text)", name: "idx_organizations_tax_id_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_organizations_on_deleted_at"
    t.index ["onboarding_status"], name: "index_organizations_on_onboarding_status"
    t.check_constraint "onboarding_current_step >= 1 AND onboarding_current_step <= 5", name: "check_organizations_onboarding_current_step"
    t.check_constraint "onboarding_status::text = ANY (ARRAY['pending'::character varying, 'in_progress'::character varying, 'completed'::character varying]::text[])", name: "check_organizations_onboarding_status"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'suspended'::character varying]::text[])", name: "check_organizations_status"
  end

  create_table "payment_integrations", force: :cascade do |t|
    t.jsonb "configuration", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "organization_id", null: false
    t.string "provider", limit: 30, null: false
    t.string "status", limit: 20, default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_payment_integrations_on_deleted_at"
    t.index ["organization_id", "provider"], name: "idx_payment_integrations_org_provider_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_payment_integrations_on_organization_id"
    t.check_constraint "provider::text = ANY (ARRAY['card'::character varying, 'qr'::character varying]::text[])", name: "check_payment_integrations_provider"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'active'::character varying, 'inactive'::character varying]::text[])", name: "check_payment_integrations_status"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "code", limit: 80, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description"
    t.string "module_name", limit: 50, null: false
    t.string "name", limit: 80, null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_permissions_on_code", unique: true
    t.index ["deleted_at", "status"], name: "index_permissions_on_deleted_at_and_status"
    t.index ["deleted_at"], name: "index_permissions_on_deleted_at"
    t.index ["module_name", "status"], name: "index_permissions_on_module_name_and_status"
    t.index ["status"], name: "index_permissions_on_status"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "check_permissions_status"
  end

  create_table "products", force: :cascade do |t|
    t.string "barcode"
    t.bigint "category_id"
    t.string "code", null: false
    t.decimal "cost", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.boolean "featured", default: false
    t.string "image_url"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0
    t.decimal "price", precision: 12, scale: 2, default: "0.0", null: false
    t.bigint "sat_tax_id"
    t.bigint "sat_unit_key_id"
    t.string "sku"
    t.string "slug"
    t.string "status", default: "active", null: false
    t.string "tracking_mode", default: "none", null: false
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0
    t.index ["barcode"], name: "index_products_on_barcode", where: "(deleted_at IS NULL)"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.index ["featured"], name: "index_products_on_featured"
    t.index ["organization_id", "code"], name: "idx_products_org_code", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id", "sku"], name: "idx_products_org_sku", unique: true, where: "((deleted_at IS NULL) AND (sku IS NOT NULL))"
    t.index ["organization_id", "slug"], name: "idx_products_org_slug", unique: true, where: "((deleted_at IS NULL) AND (slug IS NOT NULL))"
    t.index ["organization_id"], name: "index_products_on_organization_id"
    t.index ["position"], name: "index_products_on_position"
    t.index ["sat_tax_id"], name: "index_products_on_sat_tax_id"
    t.index ["sat_unit_key_id"], name: "index_products_on_sat_unit_key_id"
    t.check_constraint "tracking_mode::text = ANY (ARRAY['none'::character varying, 'lot'::character varying, 'serial'::character varying]::text[])", name: "chk_products_tracking_mode"
  end

  create_table "purchase_approvals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "decided_by_id", null: false
    t.string "decision", null: false
    t.datetime "deleted_at"
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "purchase_order_id", null: false
    t.datetime "updated_at", null: false
    t.index ["decided_by_id"], name: "index_purchase_approvals_on_decided_by_id"
    t.index ["organization_id"], name: "index_purchase_approvals_on_organization_id"
    t.index ["purchase_order_id"], name: "index_purchase_approvals_on_purchase_order_id"
  end

  create_table "purchase_cost_allocations", force: :cascade do |t|
    t.decimal "additional_discount_amount", precision: 18, scale: 6, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.decimal "extra_expenses_amount", precision: 18, scale: 6, default: "0.0", null: false
    t.decimal "freight_amount", precision: 18, scale: 6, null: false
    t.decimal "goods_amount", precision: 18, scale: 6, null: false
    t.bigint "goods_receipt_item_id", null: false
    t.decimal "insurance_amount", precision: 18, scale: 6, null: false
    t.decimal "landed_unit_cost", precision: 18, scale: 6, null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_receipt_item_id"], name: "idx_purchase_cost_allocation_receipt_item", unique: true
    t.index ["goods_receipt_item_id"], name: "index_purchase_cost_allocations_on_goods_receipt_item_id"
    t.index ["organization_id"], name: "index_purchase_cost_allocations_on_organization_id"
  end

  create_table "purchase_event_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "event_key", limit: 64, null: false
    t.bigint "organization_id", null: false
    t.bigint "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_key"], name: "index_purchase_event_deliveries_on_event_key", unique: true
    t.index ["organization_id"], name: "index_purchase_event_deliveries_on_organization_id"
    t.index ["recipient_id"], name: "index_purchase_event_deliveries_on_recipient_id"
  end

  create_table "purchase_order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.decimal "discount_percent", precision: 6, scale: 3, default: "0.0", null: false
    t.decimal "nonrecoverable_tax", precision: 14, scale: 4, default: "0.0", null: false
    t.bigint "product_id", null: false
    t.bigint "purchase_order_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.bigint "supplier_product_id"
    t.decimal "unit_price", precision: 14, scale: 4, null: false
    t.decimal "units_per_package", precision: 14, scale: 4, default: "1.0", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_order_items_on_product_id"
    t.index ["purchase_order_id"], name: "index_purchase_order_items_on_purchase_order_id"
    t.index ["supplier_product_id"], name: "index_purchase_order_items_on_supplier_product_id"
    t.check_constraint "discount_percent >= 0::numeric AND discount_percent <= 100::numeric", name: "chk_purchase_order_items_discount"
    t.check_constraint "quantity > 0::numeric AND units_per_package > 0::numeric AND unit_price >= 0::numeric", name: "chk_purchase_order_items_quantities"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.bigint "branch_id", null: false
    t.datetime "cancelled_at"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at"
    t.decimal "exchange_rate", precision: 18, scale: 8, default: "1.0", null: false
    t.date "expected_on"
    t.decimal "freight_amount", precision: 14, scale: 4, default: "0.0", null: false
    t.decimal "insurance_amount", precision: 14, scale: 4, default: "0.0", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "purchase_quotation_id"
    t.bigint "purchase_request_id"
    t.bigint "requested_by_id", null: false
    t.string "status", default: "draft", null: false
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_purchase_orders_on_approved_by_id"
    t.index ["branch_id"], name: "index_purchase_orders_on_branch_id"
    t.index ["currency_id"], name: "index_purchase_orders_on_currency_id"
    t.index ["organization_id", "code"], name: "index_purchase_orders_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_purchase_orders_on_organization_id"
    t.index ["purchase_quotation_id"], name: "index_purchase_orders_on_purchase_quotation_id"
    t.index ["purchase_request_id"], name: "index_purchase_orders_on_purchase_request_id"
    t.index ["requested_by_id"], name: "index_purchase_orders_on_requested_by_id"
    t.index ["supplier_id"], name: "index_purchase_orders_on_supplier_id"
    t.check_constraint "freight_amount >= 0::numeric AND insurance_amount >= 0::numeric AND exchange_rate > 0::numeric", name: "chk_purchase_order_expenses"
  end

  create_table "purchase_quotation_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.decimal "discount_percent", precision: 6, scale: 3, default: "0.0", null: false
    t.integer "lead_time_days", default: 0, null: false
    t.bigint "product_id", null: false
    t.bigint "purchase_quotation_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.bigint "supplier_product_id"
    t.decimal "unit_price", precision: 14, scale: 4, null: false
    t.decimal "units_per_package", precision: 14, scale: 4, default: "1.0", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_quotation_items_on_product_id"
    t.index ["purchase_quotation_id"], name: "index_purchase_quotation_items_on_purchase_quotation_id"
    t.index ["supplier_product_id"], name: "index_purchase_quotation_items_on_supplier_product_id"
    t.check_constraint "discount_percent >= 0::numeric AND discount_percent <= 100::numeric", name: "chk_purchase_quotation_items_discount"
    t.check_constraint "quantity > 0::numeric AND units_per_package > 0::numeric AND unit_price >= 0::numeric", name: "chk_purchase_quotation_items_quantities"
  end

  create_table "purchase_quotations", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at"
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "purchase_request_id"
    t.string "status", default: "draft", null: false
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.date "valid_until"
    t.index ["currency_id"], name: "index_purchase_quotations_on_currency_id"
    t.index ["organization_id", "code"], name: "index_purchase_quotations_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_purchase_quotations_on_organization_id"
    t.index ["purchase_request_id"], name: "index_purchase_quotations_on_purchase_request_id"
    t.index ["supplier_id"], name: "index_purchase_quotations_on_supplier_id"
  end

  create_table "purchase_request_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "notes"
    t.bigint "product_id", null: false
    t.bigint "purchase_request_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_request_items_on_product_id"
    t.index ["purchase_request_id"], name: "index_purchase_request_items_on_purchase_request_id"
    t.check_constraint "quantity > 0::numeric", name: "chk_purchase_request_quantity"
  end

  create_table "purchase_requests", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.date "needed_on"
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "requested_by_id", null: false
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_purchase_requests_on_branch_id"
    t.index ["organization_id", "code"], name: "index_purchase_requests_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_purchase_requests_on_organization_id"
    t.index ["requested_by_id"], name: "index_purchase_requests_on_requested_by_id"
  end

  create_table "purchase_return_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "goods_receipt_item_id", null: false
    t.text "notes"
    t.bigint "purchase_return_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.string "stock_disposition", default: "accepted", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_receipt_item_id"], name: "index_purchase_return_items_on_goods_receipt_item_id"
    t.index ["purchase_return_id"], name: "index_purchase_return_items_on_purchase_return_id"
    t.check_constraint "quantity > 0::numeric", name: "chk_purchase_return_positive"
    t.check_constraint "stock_disposition::text = ANY (ARRAY['accepted'::character varying, 'quarantined'::character varying]::text[])", name: "chk_purchase_return_stock_disposition"
  end

  create_table "purchase_returns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "goods_receipt_id", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.datetime "processed_at"
    t.string "reason", default: "damaged", null: false
    t.bigint "requested_by_id", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_receipt_id"], name: "index_purchase_returns_on_goods_receipt_id"
    t.index ["organization_id"], name: "index_purchase_returns_on_organization_id"
    t.index ["requested_by_id"], name: "index_purchase_returns_on_requested_by_id"
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
    t.check_constraint "person_type::text = ANY (ARRAY['F'::character varying, 'M'::character varying]::text[])"
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

  create_table "supplier_bank_accounts", force: :cascade do |t|
    t.string "account_number"
    t.string "bank_name", limit: 120
    t.string "clabe"
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, default: "MXN", null: false
    t.datetime "deleted_at"
    t.string "holder_name", limit: 180, null: false
    t.string "last_four", limit: 4
    t.bigint "organization_id", null: false
    t.boolean "primary", default: false, null: false
    t.string "sat_bank_code", limit: 3
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_supplier_bank_accounts_on_deleted_at"
    t.index ["organization_id", "supplier_id", "primary"], name: "idx_supplier_bank_accounts_org_supplier"
    t.index ["organization_id"], name: "index_supplier_bank_accounts_on_organization_id"
    t.index ["supplier_id", "primary"], name: "idx_supplier_one_primary_bank_account", unique: true, where: "((\"primary\" = true) AND (deleted_at IS NULL))"
    t.index ["supplier_id"], name: "index_supplier_bank_accounts_on_supplier_id"
  end

  create_table "supplier_credit_allocations", force: :cascade do |t|
    t.bigint "account_payable_id", null: false
    t.decimal "amount", precision: 18, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "organization_id", null: false
    t.bigint "supplier_credit_note_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_payable_id"], name: "index_supplier_credit_allocations_on_account_payable_id"
    t.index ["organization_id"], name: "index_supplier_credit_allocations_on_organization_id"
    t.index ["supplier_credit_note_id", "account_payable_id"], name: "idx_supplier_credit_allocation_unique", unique: true
    t.index ["supplier_credit_note_id"], name: "index_supplier_credit_allocations_on_supplier_credit_note_id"
    t.check_constraint "amount > 0::numeric", name: "chk_supplier_credit_allocation_amount"
  end

  create_table "supplier_credit_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at"
    t.string "folio", limit: 60
    t.date "issued_on", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "purchase_return_id"
    t.string "status", limit: 20, default: "draft", null: false
    t.bigint "supplier_id", null: false
    t.bigint "supplier_invoice_id"
    t.decimal "total", precision: 18, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36
    t.index ["created_by_id"], name: "index_supplier_credit_notes_on_created_by_id"
    t.index ["currency_id"], name: "index_supplier_credit_notes_on_currency_id"
    t.index ["organization_id", "uuid"], name: "idx_supplier_credit_notes_org_uuid", unique: true, where: "(uuid IS NOT NULL)"
    t.index ["organization_id"], name: "index_supplier_credit_notes_on_organization_id"
    t.index ["purchase_return_id"], name: "index_supplier_credit_notes_on_purchase_return_id"
    t.index ["supplier_id"], name: "index_supplier_credit_notes_on_supplier_id"
    t.index ["supplier_invoice_id"], name: "index_supplier_credit_notes_on_supplier_invoice_id"
    t.check_constraint "total > 0::numeric", name: "chk_supplier_credit_note_amount"
  end

  create_table "supplier_event_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "event_key", limit: 64, null: false
    t.bigint "recipient_id", null: false
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_key"], name: "index_supplier_event_deliveries_on_event_key", unique: true
    t.index ["recipient_id"], name: "index_supplier_event_deliveries_on_recipient_id"
    t.index ["supplier_id"], name: "index_supplier_event_deliveries_on_supplier_id"
  end

  create_table "supplier_invoice_lines", force: :cascade do |t|
    t.decimal "amount", precision: 18, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "description", limit: 500, null: false
    t.decimal "quantity", precision: 18, scale: 6, null: false
    t.bigint "supplier_invoice_id", null: false
    t.decimal "unit_price", precision: 18, scale: 6, null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_invoice_id"], name: "index_supplier_invoice_lines_on_supplier_invoice_id"
    t.check_constraint "quantity > 0::numeric AND unit_price >= 0::numeric AND amount >= 0::numeric", name: "chk_supplier_invoice_lines"
  end

  create_table "supplier_invoice_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "goods_receipt_id", null: false
    t.bigint "supplier_invoice_id", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_receipt_id"], name: "index_supplier_invoice_receipts_on_goods_receipt_id"
    t.index ["supplier_invoice_id", "goods_receipt_id"], name: "idx_supplier_invoice_receipt_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["supplier_invoice_id"], name: "index_supplier_invoice_receipts_on_supplier_invoice_id"
  end

  create_table "supplier_invoices", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at"
    t.decimal "discount", precision: 18, scale: 2, default: "0.0", null: false
    t.date "due_on", null: false
    t.decimal "exchange_rate", precision: 18, scale: 8, default: "1.0", null: false
    t.string "folio", limit: 60
    t.date "issued_on", null: false
    t.string "issuer_rfc", limit: 13
    t.text "notes"
    t.bigint "organization_id", null: false
    t.string "payment_method", limit: 3
    t.datetime "posted_at"
    t.bigint "purchase_order_id"
    t.date "received_on", null: false
    t.string "receiver_rfc", limit: 13
    t.string "sat_response_code", limit: 120
    t.string "sat_status", limit: 30
    t.datetime "sat_verified_at"
    t.string "series", limit: 30
    t.string "source", limit: 20, default: "manual", null: false
    t.string "status", limit: 20, default: "draft", null: false
    t.decimal "subtotal", precision: 18, scale: 2, default: "0.0", null: false
    t.bigint "supplier_id", null: false
    t.decimal "tax_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 18, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36
    t.index ["created_by_id"], name: "index_supplier_invoices_on_created_by_id"
    t.index ["currency_id"], name: "index_supplier_invoices_on_currency_id"
    t.index ["organization_id", "due_on", "status"], name: "idx_on_organization_id_due_on_status_b67ca610f8"
    t.index ["organization_id", "uuid"], name: "idx_supplier_invoices_org_uuid", unique: true, where: "(uuid IS NOT NULL)"
    t.index ["organization_id"], name: "index_supplier_invoices_on_organization_id"
    t.index ["purchase_order_id"], name: "index_supplier_invoices_on_purchase_order_id"
    t.index ["supplier_id", "issued_on"], name: "index_supplier_invoices_on_supplier_id_and_issued_on"
    t.index ["supplier_id"], name: "index_supplier_invoices_on_supplier_id"
    t.check_constraint "total >= 0::numeric AND subtotal >= 0::numeric AND discount >= 0::numeric AND tax_amount >= 0::numeric AND exchange_rate > 0::numeric", name: "chk_supplier_invoices_amounts"
  end

  create_table "supplier_payment_allocations", force: :cascade do |t|
    t.bigint "account_payable_id", null: false
    t.decimal "amount", precision: 18, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "organization_id", null: false
    t.bigint "supplier_payment_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_payable_id"], name: "index_supplier_payment_allocations_on_account_payable_id"
    t.index ["organization_id"], name: "index_supplier_payment_allocations_on_organization_id"
    t.index ["supplier_payment_id", "account_payable_id"], name: "idx_supplier_payment_allocation_unique", unique: true
    t.index ["supplier_payment_id"], name: "index_supplier_payment_allocations_on_supplier_payment_id"
    t.check_constraint "amount > 0::numeric", name: "chk_supplier_payment_allocation_amount"
  end

  create_table "supplier_payments", force: :cascade do |t|
    t.decimal "amount", precision: 18, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at"
    t.text "notes"
    t.bigint "organization_id", null: false
    t.date "paid_on", null: false
    t.datetime "posted_at"
    t.string "reference", limit: 120
    t.datetime "reversed_at"
    t.string "status", limit: 20, default: "draft", null: false
    t.bigint "supplier_bank_account_id"
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_supplier_payments_on_created_by_id"
    t.index ["currency_id"], name: "index_supplier_payments_on_currency_id"
    t.index ["organization_id", "supplier_id", "paid_on"], name: "idx_on_organization_id_supplier_id_paid_on_892ea8c286"
    t.index ["organization_id"], name: "index_supplier_payments_on_organization_id"
    t.index ["supplier_bank_account_id"], name: "index_supplier_payments_on_supplier_bank_account_id"
    t.index ["supplier_id"], name: "index_supplier_payments_on_supplier_id"
    t.check_constraint "amount > 0::numeric", name: "chk_supplier_payment_amount"
  end

  create_table "supplier_product_prices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at"
    t.decimal "discount_percent", precision: 6, scale: 3, default: "0.0", null: false
    t.date "effective_on", null: false
    t.decimal "freight_amount", precision: 14, scale: 4, default: "0.0", null: false
    t.decimal "nonrecoverable_tax", precision: 14, scale: 4, default: "0.0", null: false
    t.string "presentation_name", limit: 80, null: false
    t.decimal "purchase_price", precision: 14, scale: 4, null: false
    t.bigint "recorded_by_id"
    t.bigint "supplier_product_id", null: false
    t.decimal "units_per_package", precision: 14, scale: 4, null: false
    t.index ["currency_id"], name: "index_supplier_product_prices_on_currency_id"
    t.index ["recorded_by_id"], name: "index_supplier_product_prices_on_recorded_by_id"
    t.index ["supplier_product_id", "effective_on", "created_at"], name: "idx_supplier_prices_history"
    t.index ["supplier_product_id"], name: "index_supplier_product_prices_on_supplier_product_id"
    t.check_constraint "units_per_package > 0::numeric AND purchase_price >= 0::numeric", name: "chk_supplier_history_values"
  end

  create_table "supplier_products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at"
    t.decimal "discount_percent", precision: 6, scale: 3, default: "0.0", null: false
    t.decimal "freight_amount", precision: 14, scale: 4, default: "0.0", null: false
    t.integer "lead_time_days", default: 0, null: false
    t.decimal "minimum_quantity", precision: 14, scale: 4, default: "1.0", null: false
    t.decimal "nonrecoverable_tax", precision: 14, scale: 4, default: "0.0", null: false
    t.bigint "organization_id", null: false
    t.boolean "preferred", default: false, null: false
    t.string "presentation_name", limit: 80, default: "Unit", null: false
    t.bigint "product_id", null: false
    t.decimal "purchase_price", precision: 14, scale: 4, default: "0.0", null: false
    t.string "supplier_barcode", limit: 80
    t.bigint "supplier_id", null: false
    t.string "supplier_sku", limit: 80
    t.decimal "units_per_package", precision: 14, scale: 4, default: "1.0", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_supplier_products_on_currency_id"
    t.index ["organization_id", "product_id"], name: "idx_supplier_products_one_preferred", unique: true, where: "((preferred = true) AND (deleted_at IS NULL))"
    t.index ["organization_id", "supplier_id", "product_id", "presentation_name"], name: "idx_supplier_products_active_pair", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_supplier_products_on_organization_id"
    t.index ["product_id"], name: "index_supplier_products_on_product_id"
    t.index ["supplier_id"], name: "index_supplier_products_on_supplier_id"
    t.check_constraint "discount_percent >= 0::numeric AND discount_percent <= 100::numeric", name: "chk_supplier_product_discount"
    t.check_constraint "purchase_price >= 0::numeric AND freight_amount >= 0::numeric AND nonrecoverable_tax >= 0::numeric", name: "chk_supplier_product_costs"
    t.check_constraint "units_per_package > 0::numeric", name: "chk_supplier_product_factor"
  end

  create_table "supplier_schedules", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.time "ends_at"
    t.string "kind", null: false
    t.text "notes"
    t.time "starts_at", null: false
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["branch_id"], name: "index_supplier_schedules_on_branch_id"
    t.index ["deleted_at"], name: "index_supplier_schedules_on_deleted_at"
    t.index ["supplier_id", "branch_id", "kind", "weekday", "starts_at"], name: "idx_supplier_schedules_unique_slot", unique: true, where: "(deleted_at IS NULL)"
    t.index ["supplier_id"], name: "index_supplier_schedules_on_supplier_id"
    t.check_constraint "kind::text = ANY (ARRAY['visit'::character varying, 'order'::character varying, 'delivery'::character varying]::text[])", name: "chk_supplier_schedules_kind"
    t.check_constraint "weekday >= 0 AND weekday <= 6", name: "chk_supplier_schedules_weekday"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "alias_name", limit: 100
    t.string "classification", limit: 30
    t.string "code", limit: 30, null: false
    t.datetime "created_at", null: false
    t.integer "credit_days", default: 0, null: false
    t.decimal "credit_limit", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "currency_id", null: false
    t.datetime "deleted_at", precision: nil
    t.decimal "discount_percent", precision: 5, scale: 2, default: "0.0", null: false
    t.string "email", limit: 150
    t.string "legal_name", limit: 150
    t.decimal "minimum_order_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.string "name", limit: 150, null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.string "person_type", limit: 20
    t.string "phone", limit: 30
    t.string "postal_code", limit: 5
    t.bigint "responsible_user_id"
    t.string "rfc", limit: 13
    t.bigint "sat_fiscal_regime_id"
    t.string "status", limit: 20, default: "active", null: false
    t.text "tags", default: [], null: false, array: true
    t.string "trade_name", limit: 150
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_suppliers_on_currency_id"
    t.index ["deleted_at"], name: "index_suppliers_on_deleted_at"
    t.index ["email"], name: "index_suppliers_on_email"
    t.index ["organization_id", "code"], name: "idx_suppliers_organization_code_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id", "name"], name: "idx_suppliers_org_name_active", where: "(deleted_at IS NULL)"
    t.index ["organization_id", "rfc"], name: "idx_suppliers_organization_rfc_active", unique: true, where: "((rfc IS NOT NULL) AND ((rfc)::text <> ''::text) AND (deleted_at IS NULL))"
    t.index ["organization_id", "status", "name"], name: "idx_suppliers_org_status_name_active", where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_suppliers_on_organization_id"
    t.index ["phone"], name: "index_suppliers_on_phone"
    t.index ["responsible_user_id"], name: "index_suppliers_on_responsible_user_id"
    t.index ["sat_fiscal_regime_id"], name: "index_suppliers_on_sat_fiscal_regime_id"
    t.index ["status"], name: "index_suppliers_on_status"
    t.check_constraint "code::text = btrim(code::text) AND code::text <> ''::text AND code::text ~ '^[A-Za-z0-9_-]+$'::text", name: "chk_suppliers_code_format"
    t.check_constraint "credit_days >= 0 AND credit_days <= 365", name: "chk_supplier_credit_days"
    t.check_constraint "credit_limit >= 0::numeric AND minimum_order_amount >= 0::numeric", name: "chk_supplier_amounts"
    t.check_constraint "discount_percent >= 0::numeric AND discount_percent <= 100::numeric", name: "chk_supplier_discount"
    t.check_constraint "name::text = btrim(name::text) AND name::text <> ''::text", name: "chk_suppliers_name_format"
    t.check_constraint "postal_code IS NULL OR postal_code::text = ''::text OR postal_code::text ~ '^[0-9]{5}$'::text", name: "chk_suppliers_postal_code_format"
    t.check_constraint "rfc IS NULL OR rfc::text = ''::text OR rfc::text ~ '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'::text", name: "chk_suppliers_rfc_format"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "chk_suppliers_status"
  end

  create_table "system_role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "permission_id", null: false
    t.bigint "system_role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_system_role_permissions_on_deleted_at"
    t.index ["permission_id"], name: "index_system_role_permissions_on_permission_id"
    t.index ["system_role_id", "permission_id"], name: "idx_system_role_permissions_unique", unique: true
    t.index ["system_role_id"], name: "index_system_role_permissions_on_system_role_id"
  end

  create_table "system_roles", force: :cascade do |t|
    t.string "code", limit: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description"
    t.string "name", limit: 50, null: false
    t.string "role_type", limit: 20, null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_system_roles_on_code", unique: true
    t.index ["created_at"], name: "index_system_roles_on_created_at"
    t.index ["deleted_at"], name: "index_system_roles_on_deleted_at"
    t.index ["name", "role_type"], name: "index_system_roles_on_name_and_role_type", unique: true
    t.index ["role_type", "status"], name: "index_system_roles_on_role_type_and_status"
    t.check_constraint "deleted_at IS NULL AND status::text <> 'deprecated'::text OR deleted_at IS NOT NULL", name: "check_system_roles_deleted_status"
    t.check_constraint "role_type::text = ANY (ARRAY['system'::character varying, 'branch'::character varying]::text[])", name: "check_system_roles_role_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'deprecated'::character varying]::text[])", name: "check_system_roles_status"
  end

  create_table "terminals", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.string "code", limit: 40, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "name", limit: 80, null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index "branch_id, lower((code)::text)", name: "idx_terminals_branch_code_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["branch_id"], name: "index_terminals_on_branch_id"
    t.index ["deleted_at"], name: "index_terminals_on_deleted_at"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "check_terminals_status"
  end

  create_table "translates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "key", limit: 255, null: false
    t.bigint "language_id"
    t.string "locale", limit: 10
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["deleted_at"], name: "index_translates_on_deleted_at"
    t.index ["key", "locale"], name: "index_translates_on_key_and_locale", unique: true, where: "(deleted_at IS NULL)"
    t.index ["key"], name: "index_translates_on_key"
    t.index ["language_id", "key"], name: "index_translates_on_language_id_and_key", unique: true, where: "(deleted_at IS NULL)"
    t.index ["language_id"], name: "index_translates_on_language_id"
    t.index ["locale"], name: "index_translates_on_locale"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "branch_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "system_role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["branch_id"], name: "index_user_roles_on_branch_id"
    t.index ["deleted_at"], name: "index_user_roles_on_deleted_at"
    t.index ["system_role_id"], name: "index_user_roles_on_system_role_id"
    t.index ["user_id", "system_role_id", "branch_id"], name: "idx_user_roles_branch_unique", unique: true, where: "((deleted_at IS NULL) AND (branch_id IS NOT NULL))"
    t.index ["user_id", "system_role_id"], name: "idx_user_roles_global_unique", unique: true, where: "((deleted_at IS NULL) AND (branch_id IS NULL))"
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "current_session_token"
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.datetime "deleted_at", precision: nil
    t.string "email", default: "", null: false
    t.bigint "employee_id"
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
    t.boolean "sidebar_collapsed", default: false, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "status", default: "active", null: false
    t.datetime "terms_accepted_at"
    t.string "theme", limit: 50, default: "theme-material-red", null: false
    t.string "unique_session_id"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "user_type", null: false
    t.string "username"
    t.index "lower((email)::text)", name: "idx_users_email", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email", "status"], name: "index_users_on_email_and_status"
    t.index ["employee_id"], name: "index_users_on_employee_id"
    t.index ["language_id"], name: "index_users_on_language_id", where: "(language_id IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["session_expires_at"], name: "idx_users_session_active", where: "(session_expires_at IS NOT NULL)"
    t.index ["status"], name: "idx_users_active", where: "((status)::text = 'active'::text)"
    t.index ["status"], name: "index_users_on_status"
    t.index ["user_type", "status"], name: "index_users_on_user_type_and_status"
    t.index ["user_type"], name: "index_users_on_user_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'blocked'::character varying, 'suspended'::character varying, 'deleted'::character varying]::text[])", name: "chk_users_status"
    t.check_constraint "user_type::text = ANY (ARRAY['employee'::character varying, 'customer'::character varying, 'supplier'::character varying]::text[])", name: "chk_users_user_type"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "account_payables", "organizations"
  add_foreign_key "account_payables", "supplier_invoices"
  add_foreign_key "account_payables", "suppliers"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "countries"
  add_foreign_key "branches", "organizations"
  add_foreign_key "clients", "sat_fiscal_regimes"
  add_foreign_key "conversation_participants", "conversations"
  add_foreign_key "conversation_participants", "users"
  add_foreign_key "country_currencies", "countries"
  add_foreign_key "country_currencies", "currencies"
  add_foreign_key "dashboard_preferences", "users"
  add_foreign_key "demo_request_activities", "demo_requests"
  add_foreign_key "demo_request_activities", "users"
  add_foreign_key "demo_requests", "users", column: "assigned_to_id"
  add_foreign_key "employees", "organizations"
  add_foreign_key "financial_audit_events", "organizations"
  add_foreign_key "financial_audit_events", "users", column: "actor_id"
  add_foreign_key "financial_reminder_deliveries", "account_payables"
  add_foreign_key "financial_reminder_deliveries", "organizations"
  add_foreign_key "financial_reminder_deliveries", "users", column: "recipient_id"
  add_foreign_key "goods_receipt_items", "goods_receipts"
  add_foreign_key "goods_receipt_items", "purchase_order_items"
  add_foreign_key "goods_receipts", "branches"
  add_foreign_key "goods_receipts", "organizations"
  add_foreign_key "goods_receipts", "purchase_orders"
  add_foreign_key "goods_receipts", "users", column: "received_by_id"
  add_foreign_key "inventories", "branches"
  add_foreign_key "inventories", "organizations"
  add_foreign_key "inventories", "products"
  add_foreign_key "inventory_lots", "goods_receipt_items"
  add_foreign_key "inventory_lots", "inventories"
  add_foreign_key "inventory_lots", "organizations"
  add_foreign_key "inventory_movements", "inventories"
  add_foreign_key "inventory_movements", "inventory_lots"
  add_foreign_key "inventory_movements", "organizations"
  add_foreign_key "inventory_movements", "users"
  add_foreign_key "inventory_serials", "inventory_lots"
  add_foreign_key "inventory_serials", "organizations"
  add_foreign_key "membership_plan_features", "membership_features"
  add_foreign_key "membership_plan_features", "membership_plans"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users"
  add_foreign_key "onboarding_audits", "organizations"
  add_foreign_key "onboarding_audits", "users"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "organization_migrations", "organizations"
  add_foreign_key "organization_settings", "currencies", column: "base_currency_id"
  add_foreign_key "organization_settings", "organizations"
  add_foreign_key "payment_integrations", "organizations"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "organizations"
  add_foreign_key "products", "sat_taxes"
  add_foreign_key "products", "sat_unit_keys"
  add_foreign_key "purchase_approvals", "organizations"
  add_foreign_key "purchase_approvals", "purchase_orders"
  add_foreign_key "purchase_approvals", "users", column: "decided_by_id"
  add_foreign_key "purchase_cost_allocations", "goods_receipt_items"
  add_foreign_key "purchase_cost_allocations", "organizations"
  add_foreign_key "purchase_event_deliveries", "organizations"
  add_foreign_key "purchase_event_deliveries", "users", column: "recipient_id"
  add_foreign_key "purchase_order_items", "products"
  add_foreign_key "purchase_order_items", "purchase_orders"
  add_foreign_key "purchase_order_items", "supplier_products"
  add_foreign_key "purchase_orders", "branches"
  add_foreign_key "purchase_orders", "currencies"
  add_foreign_key "purchase_orders", "organizations"
  add_foreign_key "purchase_orders", "purchase_quotations"
  add_foreign_key "purchase_orders", "purchase_requests"
  add_foreign_key "purchase_orders", "suppliers"
  add_foreign_key "purchase_orders", "users", column: "approved_by_id"
  add_foreign_key "purchase_orders", "users", column: "requested_by_id"
  add_foreign_key "purchase_quotation_items", "products"
  add_foreign_key "purchase_quotation_items", "purchase_quotations"
  add_foreign_key "purchase_quotation_items", "supplier_products"
  add_foreign_key "purchase_quotations", "currencies"
  add_foreign_key "purchase_quotations", "organizations"
  add_foreign_key "purchase_quotations", "purchase_requests"
  add_foreign_key "purchase_quotations", "suppliers"
  add_foreign_key "purchase_request_items", "products"
  add_foreign_key "purchase_request_items", "purchase_requests"
  add_foreign_key "purchase_requests", "branches"
  add_foreign_key "purchase_requests", "organizations"
  add_foreign_key "purchase_requests", "users", column: "requested_by_id"
  add_foreign_key "purchase_return_items", "goods_receipt_items"
  add_foreign_key "purchase_return_items", "purchase_returns"
  add_foreign_key "purchase_returns", "goods_receipts"
  add_foreign_key "purchase_returns", "organizations"
  add_foreign_key "purchase_returns", "users", column: "requested_by_id"
  add_foreign_key "supplier_bank_accounts", "organizations"
  add_foreign_key "supplier_bank_accounts", "sat_banks", column: "sat_bank_code", primary_key: "code"
  add_foreign_key "supplier_bank_accounts", "suppliers"
  add_foreign_key "supplier_credit_allocations", "account_payables"
  add_foreign_key "supplier_credit_allocations", "organizations"
  add_foreign_key "supplier_credit_allocations", "supplier_credit_notes"
  add_foreign_key "supplier_credit_notes", "currencies"
  add_foreign_key "supplier_credit_notes", "organizations"
  add_foreign_key "supplier_credit_notes", "purchase_returns"
  add_foreign_key "supplier_credit_notes", "supplier_invoices"
  add_foreign_key "supplier_credit_notes", "suppliers"
  add_foreign_key "supplier_credit_notes", "users", column: "created_by_id"
  add_foreign_key "supplier_event_deliveries", "suppliers"
  add_foreign_key "supplier_event_deliveries", "users", column: "recipient_id"
  add_foreign_key "supplier_invoice_lines", "supplier_invoices"
  add_foreign_key "supplier_invoice_receipts", "goods_receipts"
  add_foreign_key "supplier_invoice_receipts", "supplier_invoices"
  add_foreign_key "supplier_invoices", "currencies"
  add_foreign_key "supplier_invoices", "organizations"
  add_foreign_key "supplier_invoices", "purchase_orders"
  add_foreign_key "supplier_invoices", "suppliers"
  add_foreign_key "supplier_invoices", "users", column: "created_by_id"
  add_foreign_key "supplier_payment_allocations", "account_payables"
  add_foreign_key "supplier_payment_allocations", "organizations"
  add_foreign_key "supplier_payment_allocations", "supplier_payments"
  add_foreign_key "supplier_payments", "currencies"
  add_foreign_key "supplier_payments", "organizations"
  add_foreign_key "supplier_payments", "supplier_bank_accounts"
  add_foreign_key "supplier_payments", "suppliers"
  add_foreign_key "supplier_payments", "users", column: "created_by_id"
  add_foreign_key "supplier_product_prices", "currencies"
  add_foreign_key "supplier_product_prices", "supplier_products"
  add_foreign_key "supplier_product_prices", "users", column: "recorded_by_id"
  add_foreign_key "supplier_products", "currencies"
  add_foreign_key "supplier_products", "organizations"
  add_foreign_key "supplier_products", "products"
  add_foreign_key "supplier_products", "suppliers"
  add_foreign_key "supplier_schedules", "branches"
  add_foreign_key "supplier_schedules", "suppliers"
  add_foreign_key "suppliers", "currencies"
  add_foreign_key "suppliers", "organizations"
  add_foreign_key "suppliers", "sat_fiscal_regimes"
  add_foreign_key "suppliers", "users", column: "responsible_user_id"
  add_foreign_key "system_role_permissions", "permissions"
  add_foreign_key "system_role_permissions", "system_roles"
  add_foreign_key "terminals", "branches"
  add_foreign_key "translates", "languages"
  add_foreign_key "user_roles", "branches"
  add_foreign_key "user_roles", "system_roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "users", "employees"
  add_foreign_key "users", "languages"
end
