# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog notification history', type: :model do
  let(:actor) { create(:user) }

  { UserNotification => :user, ProductNotification => :product, ClientNotification => :client,
    CategoryNotification => :category, LanguageNotification => :language }.each do |notification_class, factory|
    it "keeps #{factory} names and actor details available after archiving" do
      record = build(factory)
      record.save!
      notification_class.with(action: 'destroyed', record:, user: actor).deliver(actor, enqueue_job: false)
      event = Noticed::Event.order(:id).last
      record.update!(deleted_at: Time.current)
      event.reload

      expect(event.record).to eq(record)
      expect(event.user).to eq(actor)
      expect(event.action).to eq('destroyed')
      name = record.is_a?(User) ? record.display_name : record.name
      expect(event.message).to include(name)
    end
  end

  it 'renders status alerts for an archived account' do
    user = create(:user)
    UserStatusNotification.with(action: 'suspended', record: user, user: actor).deliver(actor, enqueue_job: false)
    event = Noticed::Event.order(:id).last
    user.update!(deleted_at: Time.current)
    event.reload
    expect(event.record).to eq(user)
    expect(event.action).to eq('suspended')
    expect(event.message).to eq(I18n.t('admin.users.status_management.notification_suspended'))
  end

  it 'keeps status alerts readable after an account is permanently removed' do
    user = create(:user)
    UserStatusNotification.with(action: 'suspended', record: user, user: actor).deliver(actor, enqueue_job: false)
    event = Noticed::Event.order(:id).last
    user.really_destroy!
    expect(event.reload.record).to be_nil
    expect(event.message).to eq(I18n.t('admin.users.status_management.notification_suspended'))
  end
end
