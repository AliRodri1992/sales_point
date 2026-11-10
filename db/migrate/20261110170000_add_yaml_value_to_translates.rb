# frozen_string_literal: true

# Track the latest YAML baseline separately from administrator overrides.
# Existing values remain untouched: legacy rows with no baseline are
# conservatively treated as customized until the first synchronization.
class AddYamlValueToTranslates < ActiveRecord::Migration[8.1]
  def change
    add_column :translates, :yaml_value, :text
  end
end
