# Primeiro acesso da influenciadora: a Gerente já cadastrou o @; ela digita o @, informa o
# e-mail e cria a senha. A conta ativa quando ela confirma pelo link enviado ao e-mail.
class FirstAccessController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 15, within: 10.minutes, only: %i[lookup create],
             with: -> { redirect_to first_access_path, alert: "Muitas tentativas. Aguarde alguns minutos." }
  layout "auth"

  def new; end

  def lookup
    @influencer = Influencer.active.find_by_handle(params[:instagram])
    return redirect_to(first_access_path(instagram: params[:instagram]), alert: "Não encontramos o @#{params[:instagram].to_s.delete_prefix('@')}. Confira o @ ou fale com a equipe Chase.") unless @influencer

    if @influencer.user&.activated?
      return redirect_to new_session_path(login: @influencer.instagram),
                         notice: "Você já tem acesso. Entre com o seu @ e a senha."
    end
    @email = @influencer.user&.email_address
    render :register
  end

  def create
    @influencer = Influencer.active.find_by_handle(params[:instagram])
    return redirect_to(first_access_path, alert: "Cadastro não encontrado.") unless @influencer
    return redirect_to(new_session_path, notice: "Você já tem acesso. Entre com o seu @ e a senha.") if @influencer.user&.activated?

    @email = params[:email_address].to_s.strip.downcase
    user = @influencer.user || @influencer.build_user(role: "influencer")
    user.assign_attributes(email_address: @email, name: @influencer.name, role: "influencer",
                           password: params[:password], password_confirmation: params[:password_confirmation])

    if params[:password].to_s.length < 6
      flash.now[:alert] = "A senha precisa ter pelo menos 6 caracteres."
      render :register, status: :unprocessable_entity
    elsif user.save
      InfluencerMailer.confirm_access(user).deliver_now
      @sent_to = helpers.mask_email(user.email_address)
      render :sent
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :register, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[FirstAccess] #{e.class}: #{e.message}")
    flash.now[:alert] = "Não conseguimos enviar o e-mail de confirmação agora. Tente de novo em instantes."
    render :register, status: :unprocessable_entity
  end

  def confirm
    user = User.find_by_token_for(:email_confirmation, params[:token])
    unless user
      return redirect_to new_session_path, alert: "Link inválido ou expirado. Faça o primeiro acesso de novo."
    end

    return redirect_to(new_session_path, alert: ApplicationController::BLOCKED_MESSAGE) if user.access_blocked?

    user.update!(activated_at: Time.current)
    start_new_session_for user
    redirect_to portal_path, notice: "E-mail confirmado! Bem-vinda à Chase Society."
  end
end
