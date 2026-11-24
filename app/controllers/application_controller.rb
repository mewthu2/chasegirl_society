class ApplicationController < ActionController::Base
  include Authentication

  helper_method :current_user, :admin?

  private

  def current_user = Current.session&.user

  def admin? = current_user&.admin?

  def require_admin
    redirect_to portal_path, alert: "Acesso restrito à equipe Chase." unless admin?
  end

  # Mês de competência vindo de ?mes=2026-11 (padrão: mês atual).
  def selected_month
    @selected_month ||= begin
      Date.strptime(params[:mes].to_s, "%Y-%m")
    rescue Date::Error
      Date.current
    end.beginning_of_month
  end
  helper_method :selected_month
end
