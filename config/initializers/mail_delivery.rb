# E-mails pelo Amazon SES — mesma conta e domínio (chasebrasil.com, DKIM verificado) do chase-orders.
# Sem AWS_SES_ACCESS_KEY_ID o Rails usa o padrão do ambiente (em dev/test nada sai de fato).
if Rails.env.production?
  ActiveSupport.on_load(:action_mailer) do
    self.default_url_options = { host: ENV.fetch("APP_HOST", "society.chasebrasil.com"), protocol: "https" }

    if ENV["AWS_SES_ACCESS_KEY_ID"].present?
      self.delivery_method = :ses_v2
      self.ses_v2_settings = {
        region: ENV.fetch("AWS_SES_REGION", "us-east-1"),
        credentials: Aws::Credentials.new(ENV["AWS_SES_ACCESS_KEY_ID"], ENV["AWS_SES_SECRET_ACCESS_KEY"])
      }
    end
  end
end
