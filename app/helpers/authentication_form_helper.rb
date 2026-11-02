# frozen_string_literal: true

# Localized ActiveModel validation feedback for authentication screens.
module AuthenticationFormHelper
  def authentication_blank_message(resource, attribute)
    resource.errors.full_message(attribute, resource.errors.generate_message(attribute, :blank))
  end

  def authentication_invalid_message(resource, attribute)
    resource.errors.full_message(attribute, resource.errors.generate_message(attribute, :invalid))
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
