# frozen_string_literal: true

# Localized ActiveModel validation feedback for authentication screens.
module AuthenticationFormHelper
  DOCUMENT_URL_ENV = { terms: 'DELTA_POS_TERMS_URL', privacy: 'DELTA_POS_PRIVACY_URL' }.freeze

  def authentication_document_url(kind)
    url = URI.parse(ENV.fetch(DOCUMENT_URL_ENV.fetch(kind), '').strip)
    url.to_s if url.is_a?(URI::HTTPS) && url.host.present? && url.userinfo.nil?
  rescue URI::InvalidURIError
    nil
  end

  def authentication_document_reference(kind)
    name = t("authentication.documents.#{kind}")
    url = authentication_document_url(kind)
    return name unless url

    link_to name, url, target: '_blank', rel: 'noopener noreferrer',
                       class: 'theme-text font-semibold underline underline-offset-2'
  end

  def authentication_documents_available?
    DOCUMENT_URL_ENV.keys.all? { |kind| authentication_document_url(kind).present? }
  end

  def authentication_blank_message(resource, attribute)
    resource.errors.full_message(attribute, resource.errors.generate_message(attribute, :blank))
  end

  def authentication_invalid_message(resource, attribute)
    resource.errors.full_message(attribute, resource.errors.generate_message(attribute, :invalid))
  end

  def authentication_minimum_length_message(resource, attribute, count:)
    resource.errors.full_message(attribute, resource.errors.generate_message(attribute, :login_too_short, count:))
  end

  def authentication_field_message(resource, attribute, id:)
    content_tag(:div, id:, role: 'status', 'aria-live': 'polite',
                      class: 'h-10 overflow-y-auto pt-1 text-xs leading-4 text-rose-700') do
      safe_join(resource.errors.full_messages_for(attribute).map do |message|
        content_tag(:p, message, class: 'font-medium', data: { server_field_error: true })
      end)
    end
  end
end
