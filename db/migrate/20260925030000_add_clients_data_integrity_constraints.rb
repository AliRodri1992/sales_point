# frozen_string_literal: true

class AddClientsDataIntegrityConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :clients,
                         "code = BTRIM(code) AND code <> '' AND code ~ '^[A-Za-z0-9_-]+$'",
                         name: 'chk_clients_code_format'

    add_check_constraint :clients,
                         "name = BTRIM(name) AND name <> ''",
                         name: 'chk_clients_name_format'

    add_check_constraint :clients,
                         "rfc IS NULL OR rfc = '' OR rfc ~ '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'",
                         name: 'chk_clients_rfc_format'

    add_check_constraint :clients,
                         "postal_code IS NULL OR postal_code = '' OR postal_code ~ '^[0-9]{5}$'",
                         name: 'chk_clients_postal_code_format'

    add_check_constraint :clients,
                         'credit_limit >= 0',
                         name: 'chk_clients_credit_limit_non_negative'

    add_check_constraint :clients,
                         "status IN ('active', 'inactive')",
                         name: 'chk_clients_status'
  end
end
