class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Chasegirl Society <naoresponda@chasebrasil.com>")
  layout "mailer"
end
