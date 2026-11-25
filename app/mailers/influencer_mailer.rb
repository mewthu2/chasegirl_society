class InfluencerMailer < ApplicationMailer
  # Primeiro acesso pelo @: confirma o e-mail que ela informou.
  def confirm_access(user)
    @user = user
    @influencer = user.influencer
    @url = first_access_confirm_url(user.generate_token_for(:email_confirmation))
    mail to: user.email_address, subject: "Confirme seu e-mail · Chase Society"
  end

  # Convite do pré-cadastro: link para ela criar a senha e completar os dados.
  def invitation(user)
    @user = user
    @influencer = user.influencer
    @url = invitation_url(user.generate_token_for(:invitation))
    @expires_on = User::INVITATION_TTL.from_now.to_date
    mail to: user.email_address, subject: "Seu convite para a Chase Society"
  end
end
