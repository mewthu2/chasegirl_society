# Pré-cadastro: a influenciadora abre o link do convite, cria a senha e completa os dados.
class InvitationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user
  layout "auth"

  PROFILE_FIELDS = %i[phone city pix_key].freeze

  def show; end

  def update
    @influencer&.assign_attributes(params.fetch(:influencer, {}).permit(*PROFILE_FIELDS))
    pw = params[:user] || {}

    if (@influencer.nil? || @influencer.valid?) && @user.activate!(password: pw[:password], password_confirmation: pw[:password_confirmation])
      @influencer&.save!
      start_new_session_for @user
      redirect_to (@user.staff? ? root_path : portal_path), notice: "Cadastro concluído! Bem-vind#{@user.staff? ? 'o(a)' : 'a'} à Chase Society."
    else
      flash.now[:alert] = (@user.errors.full_messages + @influencer&.errors&.full_messages.to_a).to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_by_token_for(:invitation, params[:token])
    return redirect_to(new_session_path, alert: "Convite inválido, expirado ou já usado. Se já criou a senha, é só entrar; senão, peça um novo convite à equipe Chase.") unless @user

    @influencer = @user.influencer
  end
end
