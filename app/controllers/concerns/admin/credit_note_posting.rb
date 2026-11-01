# frozen_string_literal: true

module Admin
  module CreditNotePosting
    def post_credit
      authorize @credit, :post?
      @credit.with_lock do
        raise ArgumentError, 'Credit already processed' unless @credit.draft?

        AccountsPayable::ValidateCreditCfdi.call(credit_note: @credit) if @credit.xml_document.attached?
        @credit.update!(status: :posted)
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'credit.posted', subject: @credit)
      end
      redirect_to admin_supplier_credit_note_path(@credit)
    rescue ArgumentError => e
      financial_error(e, admin_supplier_credit_note_path(@credit))
    end
  end
end
