# frozen_string_literal: true

# Keep recipient validation, delivery errors and editor state in one workflow.
module EmailTemplateTestSending
  ERROR_KEYS = {
    'Invalid recipient' => 'admin.email_templates.invalid_recipient',
    'Template not published' => 'admin.email_templates.test_not_published',
    'Test email limit reached' => 'admin.email_templates.test_limit_reached',
    'Unable to enqueue test email' => 'admin.email_templates.test_enqueue_failed'
  }.freeze

  def send_test
    authorize @template, :send_test?
    @test_recipient = EmailTemplates::TestRecipient.new(email: params[:email], actor: current_user)
    return render_invalid_test unless @test_recipient.valid?

    EmailTemplates::TestDelivery.call(template: @template, actor: current_user, recipient: @test_recipient.email)
    notify_email_template('test_queued')
    redirect_to admin_email_template_path(@template),
                flash: { swal_message: t('admin.email_templates.test_queued') }
  rescue ArgumentError => e
    handle_test_delivery_error(e)
  end

  private

  def handle_test_delivery_error(error)
    key = ERROR_KEYS[error.message]
    message = key ? t(key) : error.message
    if @template.status == 'published' && @template.published_version.present?
      @test_recipient.errors.add(:email, message)
      return render_invalid_test
    end

    redirect_to admin_email_template_path(@template),
                flash: { swal_message: message, swal_icon: 'error' }
  end

  def render_invalid_test
    load_show_details
    render :show, status: :unprocessable_content
  end
end
