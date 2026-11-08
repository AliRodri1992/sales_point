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
  describe 'email communication breadcrumbs' do
    let(:email_template) { EmailTemplate.new(id: 42, name: 'Order confirmation') }

    before do
      allow(email_template).to receive(:to_param).and_return('42')
      allow(helper.controller).to receive(:view_assigns).and_return('template' => email_template)
    end

    it 'translates the catalog breadcrumb in Spanish, English and Korean' do
      allow(helper).to receive(:params).and_return(controller: 'admin/email_templates', action: 'index')

      %i[es en ko].each do |locale|
        I18n.with_locale(locale) do
          expect(helper.breadcrumb_items.last).to eq(
            label: I18n.t('admin.breadcrumbs.controllers.email_templates')
          )
        end
      end
    end

    it 'links the catalog and identifies the displayed template' do
      allow(helper).to receive(:params).and_return(controller: 'admin/email_templates', action: 'show')
      expect(helper.breadcrumb_items.last(2)).to eq(
        [
          { label: I18n.t('admin.breadcrumbs.controllers.email_templates'), path: helper.admin_email_templates_path },
          { label: 'Order confirmation' }
        ]
      )
    end

    it 'links back to the template from the edit breadcrumb' do
      allow(helper).to receive(:params).and_return(controller: 'admin/email_templates', action: 'edit')
      expect(helper.breadcrumb_items[-2]).to include(
        label: 'Order confirmation', path: helper.admin_email_template_path(email_template)
      )
      expect(helper.breadcrumb_items.last[:label]).to eq(I18n.t('admin.email_templates.edit'))
    end

    it 'keeps branding and sender settings under the localized catalog' do
      %w[email_branding_settings email_sender_settings].each do |controller|
        allow(helper).to receive(:params).and_return(controller: "admin/#{controller}", action: 'edit')
        items = helper.breadcrumb_items
        expect(items[-2][:path]).to eq(helper.admin_email_templates_path)
        expect(items.last[:label]).to eq(I18n.t("admin.breadcrumbs.controllers.#{controller}"))
      end
    end
  end
end
