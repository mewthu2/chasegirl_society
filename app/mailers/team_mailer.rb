class TeamMailer < ApplicationMailer
  # Convite para a equipe Chase (Admin/Gerente) criar a senha.
  def invitation(user)
    @user = user
    @url = invitation_url(user.generate_token_for(:invitation))
    @expires_on = User::INVITATION_TTL.from_now.to_date
    mail to: user.email_address, subject: "Seu acesso de #{user.role_label} na Chasegirl Society"
  end
end
