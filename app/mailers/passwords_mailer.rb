class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    @url = edit_password_url(user.password_reset_token)
    mail to: user.email_address, subject: "Redefinir sua senha · Chasegirl Society"
  end
end
