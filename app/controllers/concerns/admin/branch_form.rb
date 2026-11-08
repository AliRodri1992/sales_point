# frozen_string_literal: true

module Admin
  module BranchForm
    private

    def branch_params
      params.expect(
        branch: [
          :name,
          :code,
          :contact_email,
          :notes,
          { phones_attributes: [%i[id number country_code kind label extension primary whatsapp_enabled _destroy]],
            address_attributes: %i[
              id street exterior_number interior_number neighborhood city state country_id postal_code reference_notes
            ] }
        ]
      )
    end

    def branch_identifier_taken(error)
      raise error unless @branch && %w[create update].include?(action_name)

      @branch.valid?
      @branch.errors.add(:base, t('admin.branch_workspace.identifier_conflict')) if @branch.errors.empty?
      @branch.build_address unless @branch.address
      render action_name == 'create' ? :new : :edit, status: :unprocessable_content
    end
  end
end
