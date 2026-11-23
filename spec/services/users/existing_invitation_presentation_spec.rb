# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::ExistingInvitationPresentation do
  it 'prepends the existing-account notice to a custom template without a heading and falls back to Spanish' do
    html, plain = described_class.call(html: '<p>Contenido</p>', plain: 'Contenido',
                                       locale: 'unsupported', organization_name: 'Sucursal')
    notice = I18n.t('user_invitations.existing_account', locale: :es)
    expect(Nokogiri::HTML.fragment(html).css('p').map(&:text)).to eq([notice, 'Contenido'])
    expect(plain).to eq("#{notice}\n\nContenido")
  end
end
