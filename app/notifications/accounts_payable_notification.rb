# frozen_string_literal: true

class AccountsPayableNotification < Noticed::Event
  required_param :stage

  def message
    t("admin.accounts_payable.notifications.#{params[:stage]}",
      supplier: record.supplier.name, amount: record.balance.to_s, due_on: I18n.l(record.due_on))
  end
end

