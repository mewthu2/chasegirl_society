class ApplicationController < ActionController::Base
  include Authentication

  helper_method :current_user, :staff?
  before_action :end_blocked_session

  BLOCKED_MESSAGE = "Seu acesso está desligado. Fale com a equipe Chase.".freeze

  private

  def current_user = Current.session&.user

  # Sessão aberta de influenciadora desligada (ex.: de outro aparelho): sai e volta para o login.
  def end_blocked_session
    return unless authenticated? && current_user&.access_blocked?

    terminate_session
    redirect_to new_session_path, alert: BLOCKED_MESSAGE
  end

  # Equipe Chase: Admin ou Gerente.
  def staff? = current_user&.staff?

  def require_staff
    redirect_to portal_path, alert: "Acesso restrito à equipe Chase." unless staff?
  end

  def require_admin
    redirect_to root_path, alert: "Somente o perfil Admin pode acessar." unless current_user&.admin?
  end

  # Mês de competência vindo de ?mes=2026-11 (padrão: mês atual).
  def selected_month
    @selected_month ||= begin
      Date.strptime(params[:mes].to_s, "%Y-%m")
    rescue Date::Error
      default_month
    end.beginning_of_month
  end
  helper_method :selected_month

  def default_month = Date.current
end
