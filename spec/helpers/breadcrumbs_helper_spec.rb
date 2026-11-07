# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BreadcrumbsHelper, type: :helper do
  let(:viewed) { build_stubbed(:branch, name: 'Viewed office') }

  before do
    allow(helper.controller).to receive(:view_assigns).and_return('branch' => viewed)
    allow(helper).to receive(:current_branch).and_return(build_stubbed(:branch, name: 'Working office'))
  end

  it 'labels the viewed branch rather than the branch selected for operations' do
    allow(helper).to receive(:params).and_return(controller: 'admin/branches', action: 'show')
    expect(helper.breadcrumb_items.last[:label]).to eq('Viewed office')
  end

  it 'links to the viewed record from editing' do
    allow(helper).to receive(:params).and_return(controller: 'admin/branches', action: 'edit')
    expect(helper.breadcrumb_items[2]).to include(label: 'Viewed office', path: helper.admin_branch_path(viewed))
  end
end
