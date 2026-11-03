class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('DELTA_POS_MAIL_FROM', 'from@example.com')
  layout 'mailer'
end
