# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Database supplier schedule overlap protection', type: :model do
  let(:supplier) { create(:supplier) }
  let(:branch) { create(:branch, organization: supplier.organization) }

  it 'rejects overlaps when validations are bypassed' do
    SupplierSchedule.create!(
      supplier:, branch:, kind: 'delivery', weekday: 1, starts_at: '09:00', ends_at: '11:00'
    )
    overlap = {
      supplier_id: supplier.id, branch_id: branch.id, kind: 'delivery', weekday: 1,
      starts_at: '10:00', ends_at: '12:00', created_at: Time.current, updated_at: Time.current
    }
    # rubocop:disable Rails/SkipsModelValidations
    expect { SupplierSchedule.insert_all!([overlap]) }
      # rubocop:enable Rails/SkipsModelValidations
      .to raise_error(ActiveRecord::StatementInvalid)
  end
end
