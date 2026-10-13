# frozen_string_literal: true

class AccountsPayableReminderJob < ApplicationJob
  queue_as :default

  def perform(today = Date.current)
    AccountPayable.outstanding.where(due_on: ..(today + 7.days)).includes(:organization,
                                                                          :supplier).find_each do |payable|
      next unless payable.balance.positive?

      stage = reminder_stage(payable.due_on, today)
      next unless stage

      payable.organization.users.joins(:organization_memberships)
             .where(organization_memberships: { organization_id: payable.organization_id, status: 'active' })
             .distinct.find_each do |recipient|
        next unless recipient.admin? || recipient.permission?('accounts_payable.view')

        deliver_once(payable:, recipient:, stage:, today:)
      end
    end
  end

  private

  def reminder_stage(due_on, today)
    days = (due_on - today).to_i
    return 'overdue' if days.negative?
    return 'today' if days.zero?

    "days_#{days}" if [1, 3, 7].include?(days)
  end

  def deliver_once(payable:, recipient:, stage:, today:)
    key = Digest::SHA256.hexdigest([payable.id, recipient.id, stage, today.iso8601].join(':'))
    sent = false
    FinancialReminderDelivery.transaction do
      entry = FinancialReminderDelivery.create_or_find_by!(event_key: key) do |delivery|
        delivery.organization = payable.organization
        delivery.account_payable = payable
        delivery.recipient = recipient
      end
      if entry.previously_new_record?
        AccountsPayableNotification.with(record: payable, stage:).deliver(recipient, enqueue_job: false)
        sent = true
      end
    end
    recipient.broadcast_notifications_refresh if sent
  end
end
