# frozen_string_literal: true

# Consistent attribute labels for validation messages from ActiveModel.
module FormValidationHelper
  def required_field_label(label)
    safe_join([label, ' ', tag.span('*', class: 'text-rose-600', aria: { hidden: true })])
  end

  def validation_attribute_name(object, attribute)
    model_attribute = "errors.attributes.#{object.class.name.underscore}.#{attribute}"
    general_attribute = "errors.attributes.#{attribute}"
    fallback = I18n.t(general_attribute, default: object.class.human_attribute_name(attribute))
    I18n.t(model_attribute, default: fallback)
  end
end
