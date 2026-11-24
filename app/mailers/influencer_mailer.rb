class InfluencerMailer < ApplicationMailer
  # Login, senha e link de acesso para a influenciadora.
  def access(user, password)
    @user = user
    @influencer = user.influencer
    @password = password
    @url = new_session_url
    mail to: user.email_address, subject: "Seu acesso à Chasegirl Society"
  end
end
