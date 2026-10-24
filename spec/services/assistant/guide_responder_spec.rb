# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assistant::GuideResponder do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:responder) { described_class.new(user:, organization:) }

  it 'does not expose procedures without an organization' do
    result = described_class.new(user:, organization: nil).call(question: 'Crear un producto')

    expect(result[:steps]).to be_empty
    expect(result[:source]).to eq('guide')
  end

  it 'does not expose procedures without a membership' do
    result = responder.call(question: 'Dar de alta un producto', context: 'products')

    expect(result[:steps]).to be_empty
  end

  it 'does not expose procedures after membership deactivation' do
    create(:organization_membership, organization:, user:, status: :inactive)

    expect(responder.call(question: 'Dar de alta un producto')[:steps]).to be_empty
  end

  it 'returns actionable help for an error within an active organization' do
    create(:organization_membership, organization:, user:)

    result = responder.call(question: 'No puedo guardar por un error')

    expect(result).to include(source: 'help', mood: 'concerned')
    expect(result[:steps]).not_to be_empty
  end

  it 'returns no invented steps when the question does not match any guide topic' do
    create(:organization_membership, organization:, user:)

    result = responder.call(question: 'zzzzxxxyyyqqq')

    expect(result[:steps]).to be_empty
    expect(result[:guide_url]).to eq('/admin/guide')
  end

  it 'requires category access for category procedures' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)

    expect(responder.send(:allowed?, 'categories')).to be(false)
    allow(user).to receive(:permission?).with('categories.access').and_return(true)
    expect(responder.send(:allowed?, 'categories')).to be(true)
  end

  it 'requires purchase and payable permissions for their respective modules' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)

    expect(responder.send(:allowed?, 'purchase_orders')).to be(false)
    expect(responder.send(:allowed?, 'payables')).to be(false)

    allow(user).to receive(:permission?).with('purchases.view').and_return(true)
    allow(user).to receive(:permission?).with('accounts_payable.view').and_return(true)

    expect(responder.send(:allowed?, 'purchase_orders')).to be(true)
    expect(responder.send(:allowed?, 'payables')).to be(true)
  end

  it 'denies supplier procedures without supplier listing permission' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)

    expect(responder.send(:allowed?, 'supplier_banks')).to be(false)
    expect(responder.send(:allowed?, 'supplier_calendar')).to be(false)
  end

  it 'does not hide public catalogue guide topics by default' do
    expect(responder.send(:allowed?, 'products')).to be(true)
  end

  it 'returns a documented walkthrough for a matching topic and task' do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    topic = responder.send(:accessible_topics).find { |entry| entry.fetch(:tasks).any? }
    task = topic.fetch(:tasks).first

    result = responder.call(question: task.fetch(:title), context: topic.fetch(:id))

    expect(result).to include(source: 'guide', mood: 'happy')
    expect(result[:title]).to eq(task.fetch(:title))
    expect(result[:steps]).not_to be_empty
    expect(result[:guide_url]).to include(topic.fetch(:id))
  end

  it 'boosts relevant tasks when a matching module context is supplied' do
    topic = { id: 'catalogs', title: 'Catalog management' }
    task = { title: 'Create a category' }
    tokens = responder.send(:normalized_tokens, 'Create a category')

    with_context = responder.send(:score_for, tokens, topic, task, 'catalogs')
    without_context = responder.send(:score_for, tokens, topic, task, 'unrelated')

    expect(with_context).to be > without_context
  end

  it 'allows a supplier guide procedure with a management permission but no viewing permission' do
    create(:organization_membership, organization:, user:)
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)
    allow(user).to receive(:permission?).with('suppliers.schedules.manage').and_return(true)

    expect(responder.send(:supplier_access?, 'supplier_calendar')).to be(true)
    expect(responder.send(:supplier_access?, 'supplier_fiscal')).to be(false)
  end

  it 'permits general supplier navigation when a dossier permission is present' do
    create(:organization_membership, organization:, user:)
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)
    allow(user).to receive(:permission?).with('suppliers.view').and_return(true)

    expect(responder.send(:supplier_access?, 'suppliers')).to be(true)
  end

  it 'removes repeated and irrelevant tokens from natural-language questions' do
    tokens = responder.send(:normalized_tokens, 'Cómo crear crear las categorías')

    expect(tokens).to eq(%w[crear categorias])
  end

  it 'rejects assistance without an authenticated actor before consulting membership records' do
    result = described_class.new(user: nil, organization:).call(question: 'Crear producto')

    expect(result[:steps]).to be_empty
    expect(result[:source]).to eq('guide')
  end

  it 'returns no suggested procedure when the accessible guide contains no topics' do
    create(:organization_membership, organization:, user:)
    allow(responder).to receive(:accessible_topics).and_return([])

    result = responder.call(question: 'Create a category')

    expect(result[:steps]).to be_empty
    expect(result[:title]).to be_nil
  end

  it 'keeps a concerned mood when a matching task mentions a problem without an error keyword' do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    topic = responder.send(:accessible_topics).find { |candidate| candidate.fetch(:tasks).any? }
    task = topic.fetch(:tasks).first

    result = responder.call(question: "Problema: #{task.fetch(:title)}", context: topic.fetch(:id))

    expect(result[:source]).to eq('guide')
    expect(result[:mood]).to eq('concerned')
  end

  it 'does not count stop words as meaningful guide search terms' do
    tokens = responder.send(:normalized_tokens, 'cómo puedo hacer esto para los usuarios')

    expect(tokens).to eq(['usuarios'])
  end

  it 'refuses to reveal guide content when no authenticated user exists' do
    result = described_class.new(user: nil, organization:).call(question: 'Create product')

    expect(result[:steps]).to be_empty
    expect(result[:source]).to eq('guide')
  end

  it 'normalizes short stop words into an empty search without inventing results' do
    create(:organization_membership, organization:, user:)

    result = responder.call(question: 'the and for with from', context: '')

    expect(result[:steps]).to be_empty
    expect(result[:guide_url]).to eq('/admin/guide')
  end

  it 'does not disclose specialized supplier fiscal steps through calendar access' do
    create(:organization_membership, organization:, user:)
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)
    allow(user).to receive(:permission?).with('suppliers.schedules.view').and_return(true)

    expect(responder.send(:supplier_access?, 'supplier_calendar')).to be(true)
    expect(responder.send(:supplier_access?, 'supplier_fiscal')).to be(false)
  end

  it 'does not expose administrator-only guide sections to ordinary users' do
    allow(user).to receive(:admin?).and_return(false)

    expect(responder.send(:allowed?, 'users')).to be(false)
    expect(responder.send(:allowed?, 'roles')).to be(false)
  end

  it 'allows administrator guide sections to administrators' do
    allow(user).to receive(:admin?).and_return(true)

    expect(responder.send(:allowed?, 'users')).to be(true)
  end

  it 'denies a supplier detail when only unrelated permissions are granted' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)
    allow(user).to receive(:permission?).with('suppliers.view').and_return(true)

    expect(responder.send(:supplier_access?, 'supplier_documents')).to be(false)
  end

  it 'grants a supplier detail when its management permission is present' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)
    allow(user).to receive(:permission?).with('suppliers.view').and_return(true)
    allow(user).to receive(:permission?).with('suppliers.documents.manage').and_return(true)

    expect(responder.send(:supplier_access?, 'supplier_documents')).to be(true)
  end

  it 'handles an empty question without inventing a guide match' do
    create(:organization_membership, organization:, user:)

    expect(responder.call(question: '', context: 'unrelated')[:steps]).to be_empty
  end
end
