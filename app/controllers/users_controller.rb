# Equipe Chase (Admin e Gerente). Acessos das influenciadoras ficam na ficha de cada uma.
class UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: %i[edit update destroy]

  def index
    @users = User.staff.order(:role, :name, :email_address)
  end

  def new
    @user = User.new(role: "manager")
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "Usuário criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attrs = user_params
    attrs.delete(:password) if attrs[:password].blank?
    if @user.update(attrs)
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

  private

  def set_user = @user = User.staff.find(params[:id])

  def user_params
    attrs = params.require(:user).permit(:name, :email_address, :password, :role)
    attrs[:role] = "manager" unless User::STAFF_ROLES.include?(attrs[:role])
    attrs.delete(:role) if @user == current_user # não rebaixa a si mesmo
    attrs
  end
end
