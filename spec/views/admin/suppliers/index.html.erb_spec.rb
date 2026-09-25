require 'rails_helper'

RSpec.describe 'admin/suppliers/index', type: :view do
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }
  let(:user) { create(:user) }

  before do
    create(:user_role, user:, system_role: admin_role)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:params).and_return(ActionController::Parameters.new(controller: 'admin/suppliers', action: 'index'))
    assign(:suppliers, Supplier.none)
    assign(:total_count, 0)
    assign(:total_pages, 1)
  end

  it 'renders an accessible empty state' do
    render

    expect(rendered).to include('No suppliers yet')
    expect(rendered).to include('Add your first supplier')
  end
end
