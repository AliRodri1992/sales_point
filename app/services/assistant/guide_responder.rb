# frozen_string_literal: true

module Assistant
  class GuideResponder
    MAX_STEPS = 6
    STOP_WORDS = %w[
      para como donde cuales cual esta este esto sobre una unos unas los las del
      por con que quien desde puedo puedes puede quiero hacer necesito ayudame
      dame favor paso pasos sistema modulo pantalla using from with what where
      this that please show me how create the and for
    ].freeze

    def initialize(user:, organization:)
      @user = user
      @organization = organization
    end

    def call(question:, context: '')
      return unavailable unless organization_access?
      return explain_error if question.match?(/error|validaci[oó]n|no puedo guardar|invalid|오류/i)

      selection = best_match(question, context)
      return unavailable unless selection

      topic, task = selection
      {
        reply: I18n.t('admin.assistant.found', title: task.fetch(:title)),
        title: task.fetch(:title),
        steps: task.fetch(:steps).first(MAX_STEPS),
        note: topic[:note],
        guide_url: "/admin/guide#guide-#{topic.fetch(:id)}",
        mood: question.match?(/error|fall[ao]|problema|invalid|오류/i) ? 'concerned' : 'happy',
        source: 'guide'
      }
    end

    private

    def organization_access?
      @user && @organization &&
        @user.organization_memberships.exists?(
          organization_id: @organization.id, status: :active
        )
    end

    def best_match(question, context)
      query = normalized_tokens(question)
      candidates = accessible_topics.flat_map do |topic|
        topic.fetch(:tasks).map do |task|
          [score_for(query, topic, task, context), topic, task]
        end
      end
      winner = candidates.max_by(&:first)
      return unless winner&.first&.positive?

      winner.last(2)
    end

    def score_for(query, topic, task, context)
      score = (query & normalized_tokens(task.fetch(:title))).size * 5
      score += (query & normalized_tokens(topic.fetch(:title))).size * 3
      score += 4 if normalized_tokens(topic.fetch(:id).tr('_', ' ')).intersect?(query)
      score += 2 if topic.fetch(:id) == context
      score
    end

    def normalized_tokens(text)
      I18n.transliterate(text.to_s.downcase, locale: :en)
          .scan(/[[:alnum:]]+/).reject { |word| word.length < 3 || STOP_WORDS.include?(word) }.uniq
    end

    def accessible_topics
      sections = %w[startup security catalogs suppliers purchasing finances communication]
      topics = sections.flat_map do |section|
        I18n.t("admin.user_manual.sections.#{section}", locale: :es).fetch(:topics)
      end
      topics.reject { |topic| topic[:id] == 'coming_soon' || !allowed?(topic[:id]) }
    end

    def allowed?(topic)
      return @user.admin? if Admin::GuideHelper::ADMIN_TOPICS.include?(topic)
      return permitted?('categories.access') if topic == 'categories'
      return permitted?('purchases.view') if Admin::GuideHelper::PURCHASE_TOPICS.include?(topic)
      return permitted?('accounts_payable.view') if Admin::GuideHelper::FINANCIAL_TOPICS.include?(topic)
      return supplier_access?(topic) if Admin::GuideHelper::SUPPLIER_TOPICS.include?(topic)

      true
    end

    def supplier_access?(topic)
      return false unless SupplierPolicy.new(@user, Supplier.new(organization: @organization)).index?

      permission = {
        'supplier_fiscal' => 'suppliers.fiscal.view',
        'supplier_commercial' => 'suppliers.commercial.view',
        'supplier_contacts' => 'suppliers.contacts.view',
        'supplier_addresses' => 'suppliers.addresses.view',
        'supplier_documents' => 'suppliers.documents.view',
        'supplier_calendar' => 'suppliers.schedules.view',
        'supplier_products' => 'suppliers.products.view',
        'supplier_banks' => 'accounts_payable.banks.view',
        'supplier_export' => 'suppliers.export'
      }[topic]
      permission.nil? || permitted?(permission) || permitted?(permission.sub('.view', '.manage'))
    end

    def permitted?(permission)
      @user.admin? || @user.permission?(permission)
    end

    def explain_error
      {
        reply: I18n.t('admin.assistant.error_intro'),
        title: I18n.t('admin.assistant.error_title'),
        steps: I18n.t('admin.assistant.error_steps'),
        note: nil,
        guide_url: '/admin/guide',
        mood: 'concerned',
        source: 'help'
      }
    end

    def unavailable
      {
        reply: I18n.t('admin.assistant.not_found'),
        title: nil,
        steps: [],
        note: nil,
        guide_url: '/admin/guide',
        mood: 'thinking',
        source: 'guide'
      }
    end
  end
end
