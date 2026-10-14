# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Seed permission translations' do
  ATTRIBUTES = %w[name description].freeze
  def permission_codes
    file = Rails.root.join('db/seeds.rb').read
    list = file.split('DEFAULT_PERMISSIONS = [', 2).last.split('].freeze', 2).first
    list.scan(/code: '([a-z0-9_.]+)'/).flatten
  end

  %i[es en ko].each do |locale|
    it "has a name and description for every defined permission in #{locale}" do
      missing = permission_codes.flat_map do |code|
        key = code.tr('.', '_')
        ATTRIBUTES.filter_map do |attribute|
          lookup = "admin.system_roles.permissions.#{key}.#{attribute}"
          lookup unless I18n.exists?(lookup, locale)
        end
      end

      expect(missing).to be_empty, "Missing permission translations: #{missing.join(', ')}"
    end
  end
end
