# frozen_string_literal: true

# Builds an editable snapshot without altering previously published content.
module EmailTemplateDraftContent
  def draft_content(source)
    title = source&.subject || subject
    body = source&.html_body || html_body
    plain = source&.text_body || text_body
    variables = source&.allowed_variables.presence ||
                [title, source&.preheader, body, plain].join(' ').scan(/\{\{([a-z][a-z0-9_]*)\}\}/).flatten.uniq
    { subject: title, preheader: source&.preheader.to_s, html_body: body, text_body: plain,
      allowed_variables: variables }
  end
end
