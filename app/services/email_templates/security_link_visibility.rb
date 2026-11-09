# frozen_string_literal: true

module EmailTemplates
  # A critical email action must have a visible, accessible label *after*
  # sanitization. Text in hidden descendants is not an actionable label.
  class SecurityLinkVisibility
    HIDDEN_VALUES = {
      'display' => /\Anone\z/i,
      'visibility' => /\A(?:hidden|collapse)\z/i,
      'opacity' => /\A0(?:\.0+)?\z/,
      'font-size' => /\A0(?:\.0+)?(?:px|pt|em|rem|%)?\z/i
    }.freeze

    def self.visible?(link)
      link.xpath('.//text() | .//img[@alt]').any? do |node|
        label = node.text? ? node.text : node['alt']
        label.to_s.strip.present? && visible_node?(node)
      end
    end

    def self.visible_node?(node)
      ([node] + node.ancestors).none? { |ancestor| hidden?(ancestor) }
    end

    def self.hidden?(node)
      return false unless node.element?
      return true if node.attribute('hidden') || node['aria-hidden'].to_s.casecmp?('true')

      node['style'].to_s.split(';').any? do |declaration|
        property, value = declaration.split(':', 2)
        value = value.to_s.sub(/\s*!important\s*\z/i, '').strip
        HIDDEN_VALUES[property.to_s.strip.downcase]&.match?(value)
      end
    end
  end
end
