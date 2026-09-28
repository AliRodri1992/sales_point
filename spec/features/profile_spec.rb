# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User profile', type: :feature do
  let(:user) { create(:user, username: 'Ivan', email: 'ivan@example.com') }

  before do
    sign_in user
  end

  scenario 'user views their profile' do
    visit profile_path

    expect(page).to have_content('My profile')
    expect(page).to have_content('Ivan')
    expect(page).to have_content('ivan@example.com')
    expect(page).to have_content('Personal information')
  end

  scenario 'user updates their profile' do
    visit profile_path

    fill_in 'Username', with: 'Ivan Rodriguez'
    fill_in 'Email address', with: 'ivan.rodriguez@example.com'
    click_button 'Save changes'

    expect(page).to have_content('Profile updated successfully')
    expect(user.reload.username).to eq('Ivan Rodriguez')
    expect(user.email).to eq('ivan.rodriguez@example.com')
  end
end
