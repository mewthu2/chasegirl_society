class ApplicationController < ActionController::Base
  include Authentication

  helper_method :current_user, :staff?

  private

  def current_user = Current.session&.user

  # Equipe Chase: Admin ou Gerente.
  def staff? = current_user&.staff?

  def require_staff
    redirect_to portal_path, alert: "Acesso restrito à equipe Chase." unless staff?
  end

  def require_admin
    redirect_to root_path, alert: "Somente o perfil Admin pode acessar." unless current_user&.admin?
  end

  def require_manager
    redirect_to root_path, alert: "Somente o perfil Gerente pode configurar metas e valores." unless current_user&.can_configure_contracts?
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
