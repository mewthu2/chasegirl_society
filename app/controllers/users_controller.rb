# Equipe Chase (Admin e Gerente). Novos membros recebem convite por e-mail e criam a própria senha.
# Acessos das influenciadoras ficam na ficha de cada uma.
class UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: %i[edit update destroy invite]

  def index
    @users = User.staff.order(:role, :name, :email_address)
  end

  def new
    @user = User.new(role: "manager")
  end

  def create
    @user = User.new(user_params.merge(password: SecureRandom.base58(32)))
    if @user.save
      deliver_invitation(@user, "#{@user.role_label} cadastrado")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "Usuário atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    return redirect_to(users_path, alert: "Você não pode remover a si mesmo.") if @user == current_user
    @user.destroy
    redirect_to users_path, notice: "Usuário removido."
  end

  # Convite (pré-cadastro) ou, para quem já está ativo, link de nova senha.
  def invite
    if @user.activated?
      PasswordsMailer.reset(@user).deliver_now
      redirect_to users_path, notice: "Link para redefinir a senha enviado para #{@user.email_address}."
    else
      deliver_invitation(@user, "Convite reenviado")
    end
  rescue StandardError => e
    redirect_to users_path, alert: "Não foi possível enviar o e-mail: #{e.message}"
  end

  private

  def set_user = @user = User.staff.find(params[:id])

  def user_params
    attrs = params.require(:user).permit(:name, :email_address, :role)
    attrs[:role] = "manager" unless User::STAFF_ROLES.include?(attrs[:role])
    attrs.delete(:role) if @user == current_user # não rebaixa a si mesmo
    attrs
  end

  def deliver_invitation(user, prefix)
    TeamMailer.invitation(user).deliver_now
    user.update_columns(invited_at: Time.current)
    redirect_to users_path, notice: "#{prefix}. Convite enviado para #{user.email_address} (vale 7 dias)."
  rescue StandardError => e
    Rails.logger.error("[TeamMailer] #{e.class}: #{e.message}")
    redirect_to users_path, alert: "#{prefix}, mas o convite não foi enviado (#{e.message}). Use \"Enviar convite\"."
  end
end
