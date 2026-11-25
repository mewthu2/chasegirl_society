# Conferência mensal: mostra quem cumpriu as metas do mês. Não há aprovação manual:
# o mês é aprovado sozinho quando a comprovação que fecha as metas é aprovada.
class ReviewsController < ApplicationController
  before_action :require_staff
  before_action :set_statement, except: :index

  def index
    @phase = MonthlyStatement.phase(selected_month)
    influencers = Influencer.ordered.includes(:user).select do
      _1.active_in?(selected_month) || _1.monthly_statements.for_month(selected_month).exists?
    end
    @statements = influencers.map { _1.statement_for(selected_month) }
    @counts = @statements.group_by(&:review_status).transform_values(&:size)
    @coupon_errors = @statements.count { _1.approved? && _1.coupon_status == "error" }
    @filter = params[:filtro].presence_in(MonthlyStatement::REVIEW_LABELS.keys) || "todas"
    @statements = @statements.select { _1.review_status == @filter } unless @filter == "todas"
  end

  def show
    @proofs = @statement.proofs.includes(:reviewed_by, images_attachments: :blob).recent
  end

  def reopen
    return back_with(alert: "Mês já pago: desfaça o pagamento antes.") if @statement.paid?
    @statement.reopen!
    back_with(notice: "Voltou para conferência. O a pagar foi removido#{'; o uso já liberado no cupom continua na Shopify' if @statement.coupon_done?}.")
  end

  def coupon
    @statement.increment_coupon! if @statement.approved?
    if @statement.coupon_done?
      back_with(notice: "Cupom renovado: novo limite #{@statement.coupon_usage_limit}.")
    else
      back_with(alert: @statement.coupon_error || "Aprove o mês antes de renovar o cupom.")
    end
  end

  private

  def set_statement = @statement = MonthlyStatement.find(params[:id])

  def back_with(flash_opts)
    redirect_back fallback_location: reviews_path(mes: @statement.month.strftime("%Y-%m")), **flash_opts
  end
end
