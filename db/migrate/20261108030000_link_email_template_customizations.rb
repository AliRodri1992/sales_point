# frozen_string_literal: true

class LinkEmailTemplateCustomizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :email_templates, :source_template, null: true,
                  foreign_key: { to_table: :email_templates },
                  index: { name: 'idx_email_templates_source_template' }
  end
