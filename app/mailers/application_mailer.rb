class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Chase Society <naoresponda@chasebrasil.com>")
  layout "mailer"
  before_action :attach_logo

  private

  # Logo no topo de todo e-mail, embutido (cid:), para aparecer mesmo sem carregar imagens externas.
  def attach_logo
    attachments.inline["chase-society-logo.png"] = Rails.root.join("app/assets/images/chase-society-logo.png").binread
  end
end
