require 'rails_helper'

RSpec.describe LanguagePolicy, type: :policy do
  subject(:policy) { described_class.new(user, language) }

  let(:language) { build(:language) }
  let(:user) { build(:user) }

  before do
    allow(user).to receive(:admin?).and_return(true)
  end

  it 'allows administrators to manage languages and generations' do
    expect(policy.index?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
    expect(policy.generate?).to be(true)
    expect(policy.retry_generation?).to be(true)
    expect(policy.resume_generation?).to be(true)
    expect(policy.cancel_generation?).to be(true)
  end
end
