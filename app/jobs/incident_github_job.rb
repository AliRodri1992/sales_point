class IncidentGithubJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(id)
    incident = Incident.find(id)
    return if incident.github_issue_number || !Incidents::Github.configured?

    client = Incidents::Github.new
    issue = if claim_submission(incident)
              submit(client, incident)
            else
              client.existing(incident.folio)
            end
    raise IOError, 'Issue awaiting reconciliation' unless issue

    incident.update!(github_state: 'synced', github_issue_number: issue.fetch('number'),
                     github_issue_url: issue.fetch('html_url'))
  end

  private

  def claim_submission(incident)
    incident.with_lock do
      return false unless incident.github_state == 'pending'

      incident.update!(github_state: 'sending')
    end
  end

  def submit(client, incident)
    client.create_issue(incident)
  rescue Incidents::Github::Rejected
    incident.update!(github_state: 'pending')
    raise
  end
end
