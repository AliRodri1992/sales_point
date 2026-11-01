# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Actionable user-facing messages', type: :model do
  supplier_notices = %w[
    contact_created contact_updated contact_deleted contact_restored
    address_created address_updated address_deleted address_restored
  ].freeze
  calendar_actions = %w[created updated deleted].freeze

  %i[es en ko].each do |locale|
    context "when locale is #{locale}" do
      supplier_notices.each do |notice|
        it "explains the result of supplier notification #{notice}" do
          message = I18n.t("admin.shared.notifications.supplier_activity.#{notice}", locale: locale)
          expect(message).to be_a(String)
          expect(message.length).to be >= 20
          expect(message).not_to match(/Translation missing/i)
        end
      end

      calendar_actions.each do |action|
        it "explains the calendar result for #{action}" do
          message = I18n.t("admin.supplier_calendar.messages.#{action}", locale: locale)
          expect(message).to be_a(String)
          expect(message.length).to be >= 20
        end
      end
    end
  end
end
