# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Actionable user-facing messages', type: :model do
  SUPPLIER_NOTICES = %w[
    contact_created contact_updated contact_deleted contact_restored
    address_created address_updated address_deleted address_restored
  ].freeze

  %i[es en ko].each do |locale|
    context "when locale is #{locale}" do
      SUPPLIER_NOTICES.each do |notice|
        it "explains the result of supplier notification #{notice}" do
          text = I18n.t("admin.shared.notifications.supplier_activity.#{notice}", locale: locale)
          expect(text).to be_a(String)
          expect(text.length).to be >= 35
          expect(text).not_to match(/Translation missing/i)
        end
      end

      %w[created updated deleted].each do |action|
        it "explains the calendar result for #{action}" do
          text = I18n.t("admin.supplier_calendar.flash.#{action}", locale: locale, default: nil)
          next if text.nil?

          expect(text.length).to be >= 35
        end
      end
    end
  end
end
