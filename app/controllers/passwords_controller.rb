# "Esqueci minha senha": link de redefinição por e-mail (token do has_secure_password, 15 min).
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]
  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to new_password_path, alert: "Muitas tentativas. Aguarde alguns minutos." }
  layout "auth"

  def new; end

  def create
    if (user = User.find_by(email_address: params[:email_address].to_s.strip.downcase))
      PasswordsMailer.reset(user).deliver_now
    end
    redirect_to new_session_path, notice: "Se o e-mail estiver cadastrado, enviamos um link para criar uma nova senha."
  rescue StandardError => e
    Rails.logger.error("[PasswordsMailer] #{e.class}: #{e.message}")
    redirect_to new_password_path, alert: "Não foi possível enviar o e-mail agora. Tente de novo em instantes."
  end

  def edit; end

  def update
    if params[:password].to_s.length < 6
      redirect_to edit_password_path(params[:token]), alert: "A senha precisa ter pelo menos 6 caracteres."
    elsif @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Senha alterada. Entre com a nova senha."
    else
      redirect_to edit_password_path(params[:token]), alert: "As senhas não conferem."
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: "Link inválido ou expirado. Peça um novo."
  end
end
