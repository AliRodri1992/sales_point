# frozen_string_literal: true

class EmailTemplateTestMailer < ApplicationMailer
  def sample(template_id, recipient, version_id = nil)
    template = EmailTemplate.find(template_id)
    raise ArgumentError, 'Template must be published' unless testable?(template)

    version = version_id ? template.versions.find_by!(id: version_id, status: 'published') : template.published_version
    subject, html, plain = sample_content(template, recipient, version)
    headers = EmailTemplates::Sender.headers_for(organization: template.organization)
    mail(to: recipient, subject: "[TEST] #{subject}", **headers) do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end

  private

  def testable?(template)
    template.status == 'published' && template.enabled? && template.published_version.present?
  end

  def sample_content(template, recipient, version)
    variables = EmailTemplates::SampleData.call(template)
    variables[:recipient_email] = recipient
    subject, html, plain = EmailTemplates::Renderer.new(source: version, values: variables, preview: true).render
    [subject, disable_sample_links(html), redact_sample_links(plain)]
  end

  # Test emails may show sample content, but must not include actionable example-domain links.
  def disable_sample_links(html)
    document = Nokogiri::HTML.parse(html)
    document.css('a[href]').each do |anchor|
      anchor.remove_attribute('href') if sample_link?(anchor['href'])
    end
    document.to_html
  end

  def redact_sample_links(plain)
    plain.gsub(%r{https?://(?:[a-z0-9-]+\.)*example\.(?:com|org|net)(?:/[^\s]*)?}i,
               '[test link unavailable]')
  end

  def sample_link?(url)
    uri = URI.parse(url)
    host = uri.host.to_s.downcase
    return true if url.to_s.match?(/\Amailto:[^@]+@(?:[a-z0-9-]+\.)*example\.(?:com|org|net)\z/i)

    %w[example.com example.org example.net].any? do |domain|
      host == domain || host.end_with?(".#{domain}")
    end
  rescue URI::InvalidURIError
    false
  end
end
