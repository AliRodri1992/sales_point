# frozen_string_literal: true

namespace :accounts_payable do
  desc 'Enqueue payment due-date reminders (schedule daily using your job/cron scheduler)'
  task reminders: :environment do
    AccountsPayableReminderJob.perform_later
  end
end

