require 'rails_helper'

RSpec.describe 'admin/suppliers/index', type: :view do
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }
  let(:user) { create(:user) }

  before do
    create(:user_role, user:, system_role: admin_role)
    allow(view).to receive(:current_user).and_return(user)
    params = ActionController::Parameters.new(controller: 'admin/suppliers', action: 'index')
    allow(view).to receive(:params).and_return(params)

    # Include Pundit in view context
    view.extend(Pundit::Authorization)
    allow(view).to receive(:pundit_user).and_return(user)

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
