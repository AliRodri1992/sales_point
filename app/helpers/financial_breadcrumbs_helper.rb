# frozen_string_literal: true

module FinancialBreadcrumbsHelper
  def account_payable_breadcrumb_items
    payable = controller.view_assigns['payable']
    detail = payable&.supplier_invoice&.folio.presence || t('admin.accounts_payable.payable_detail')
    financial_breadcrumb_items('payables', admin_account_payables_path, detail:)
  end

  def supplier_invoice_breadcrumb_items
    invoice = controller.view_assigns['invoice']
    detail = invoice&.folio.presence || t('admin.accounts_payable.invoice')
    financial_breadcrumb_items('invoices', admin_supplier_invoices_path,
                               detail:, new_key: 'new_invoice', edit_key: 'edit_invoice')
  end

  def supplier_payment_breadcrumb_items
    payment = controller.view_assigns['payment']
    detail = payment&.reference.presence || t('admin.accounts_payable.payment')
    financial_breadcrumb_items('payments', admin_supplier_payments_path, detail:, new_key: 'new_payment')
  end

  def supplier_credit_note_breadcrumb_items
    credit = controller.view_assigns['credit']
    detail = credit&.folio.presence || t('admin.accounts_payable.credit')
    financial_breadcrumb_items('credits', admin_supplier_credit_notes_path, detail:, new_key: 'new_credit')
  end

  private

  def financial_breadcrumb_items(section, path, detail:, new_key: nil, edit_key: nil)
    base = { label: t("admin.accounts_payable.breadcrumbs.#{section}"), path: }
    return [base.except(:path)] if params[:action] == 'index'

    label = case params[:action]
            when 'new', 'create' then new_key ? t("admin.accounts_payable.#{new_key}") : detail
            when 'edit', 'update' then edit_key ? t("admin.accounts_payable.#{edit_key}") : detail
            else detail
            end
    [base, { label: }]
  end
end
