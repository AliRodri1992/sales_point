require 'rails_helper'

RSpec.describe IncidentGithubJob do
  let(:incident) do
    Incident.create!(organization: create(:organization), reporter: create(:user), description: 'Issue')
  end
  let(:client) { instance_double(Incidents::Github) }
  let(:issue) { { 'number' => 10, 'html_url' => 'https://github.com/AliRodri1992/sales_point/issues/10' } }

  before do
    allow(Incidents::Github).to receive_messages(configured?: true, new: client)
  end

  it 'sends once and stores the issue reference' do
    expect(client).to receive(:create_issue).once.with(incident).and_return(issue)
    2.times { described_class.new.perform(incident.id) }
    expect(incident.reload.github_issue_number).to eq(10)
  end

  it 'allows a fresh attempt after GitHub explicitly rejects creation' do
    allow(client).to receive(:create_issue).and_raise(Incidents::Github::Rejected)
    expect { described_class.new.perform(incident.id) }.to raise_error(Incidents::Github::Rejected)
    expect(incident.reload.github_state).to eq('pending')
  end

  it 'reconciles an uncertain submission by folio' do
    incident.update!(github_state: 'sending')
    expect(client).to receive(:existing).with(incident.folio).and_return(issue)
    expect(client).not_to receive(:create_issue)
    described_class.new.perform(incident.id)
    expect(incident.reload.github_state).to eq('synced')
  end
end
