class InfluencerMailer < ApplicationMailer
  # Convite do pré-cadastro: link para ela criar a senha e completar os dados.
  def invitation(user)
    @user = user
    @influencer = user.influencer
    @url = invitation_url(user.generate_token_for(:invitation))
    @expires_on = User::INVITATION_TTL.from_now.to_date
    mail to: user.email_address, subject: "Seu convite para a Chase Society"
  end
end
