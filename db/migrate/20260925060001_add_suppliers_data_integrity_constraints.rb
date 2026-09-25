# frozen_string_literal: true

class AddSuppliersDataIntegrityConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :suppliers,
                         "code = BTRIM(code) AND code <> '' AND code ~ '^[A-Za-z0-9_-]+$'",
                         name: 'chk_suppliers_code_format'
    add_check_constraint :suppliers,
                         "name = BTRIM(name) AND name <> ''",
                         name: 'chk_suppliers_name_format'
    add_check_constraint :suppliers,
                         "rfc IS NULL OR rfc = '' OR rfc ~ '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'",
                         name: 'chk_suppliers_rfc_format'
    add_check_constraint :suppliers,
                         "postal_code IS NULL OR postal_code = '' OR postal_code ~ '^[0-9]{5}$'",
                         name: 'chk_suppliers_postal_code_format'
    add_check_constraint :suppliers,
                         "status IN ('active', 'inactive')",
                         name: 'chk_suppliers_status'
  end
end
