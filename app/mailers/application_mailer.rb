class ApplicationMailer < ActionMailer::Base
  # Production must never send mail from a placeholder address.
  sender = if Rails.env.production?
             ENV.fetch('DELTA_POS_MAIL_FROM')
           else
             ENV.fetch('DELTA_POS_MAIL_FROM', 'from@example.com')
           end
  if Rails.env.production? && (!sender.match?(URI::MailTo::EMAIL_REGEXP) ||
                               sender.end_with?('@example.com'))
    raise 'DELTA_POS_MAIL_FROM must be a valid, authorized production sender'
  end

  default from: sender
  layout 'mailer'
end
