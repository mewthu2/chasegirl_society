class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Muitas tentativas. Aguarde alguns minutos." }
  layout "auth"

  def new
    redirect_to root_path if authenticated?
  end

  # Influenciadora entra com e-mail ou @ do Instagram; equipe com e-mail.
  def create
    user = User.find_by_login(params[:login])
    tab = params[:perfil].presence_in(%w[influencer equipe]) || "influencer"

    if user&.authenticate(params[:password].to_s)
      if user.access_blocked?
        redirect_to new_session_path, alert: ApplicationController::BLOCKED_MESSAGE
      elsif user.activated?
        start_new_session_for user
        redirect_to after_authentication_url
      else
        redirect_to new_session_path(perfil: tab, login: params[:login]),
                    alert: "Falta confirmar seu e-mail: clique no link que enviamos para #{helpers.mask_email(user.email_address)}."
      end
    else
      redirect_to new_session_path(perfil: tab, login: params[:login]),
                  alert: tab == "influencer" ? "Login ou senha incorretos. Primeira vez aqui? Use \"Primeiro acesso\"." : "E-mail ou senha incorretos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
