# frozen_string_literal: true

module SupplierBankAccountReview
  def perform_bank_review
    authorize @account, :review?
    decision = params[:decision].to_s
    unless %w[verified rejected pending].include?(decision) && @account.status == 'active'
      return redirect_to admin_supplier_bank_accounts_path(@supplier),
                         alert: t('admin.supplier_bank_details.status')
    end

    return invalid_verification_date if decision == 'verified' && verified_bank_date.nil?

    save_review!(decision)
    redirect_to admin_supplier_bank_accounts_path(@supplier)
  end

  private

  def invalid_verification_date
    redirect_to admin_supplier_bank_accounts_path(@supplier),
                alert: t('admin.supplier_bank_details.verification_date_required')
  end

  def save_review!(decision)
    verification_date = verified_bank_date if decision == 'verified'
    attributes = { verification_status: decision }
    attributes[:verified_at] = verification_date.in_time_zone if verification_date
    @account.update!(attributes)
    FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                event: 'bank_account.verification_reviewed', subject: @account,
                                details: { decision: decision, verified_on: verification_date&.iso8601 })
  end

  def verified_bank_date
    date = Date.iso8601(params[:verified_on].to_s)
    date unless date.future?
  rescue Date::Error
    nil
  end
end
