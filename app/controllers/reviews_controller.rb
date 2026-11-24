# Conferência mensal: de 1 a 10 do mês seguinte a equipe confere as entregas do mês.
# Aprovar = renova o cupom (+1 uso) e cria o "a pagar" do combinado (vence dia 10).
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
    @filter = params[:filtro].presence_in(MonthlyStatement::REVIEW_LABELS.keys) || "todas"
    @statements = @statements.select { _1.review_status == @filter } unless @filter == "todas"
  end

  def show
    @proofs = @statement.proofs.includes(:reviewed_by, images_attachments: :blob).recent
  end

  def approve
    return back_with(alert: "Mês já pago: desfaça o pagamento antes.") if @statement.paid?
    if @statement.phase == :running
      return back_with(alert: "#{helpers.month_label(@statement.month)} ainda está em andamento. A conferência começa em #{helpers.date_br(@statement.review_start)}.")
    end

    amount = parse_money(params[:amount])
    @statement.approve!(by: current_user, amount:, renew_coupon: params[:renew_coupon] != "0", note: params[:note])
    msg = "#{@statement.influencer.name}: mês aprovado, a pagar #{helpers.brl(@statement.amount_payable)} em #{helpers.date_br(@statement.due_on)}."
    msg += case @statement.coupon_status
           when "done" then " Cupom renovado (limite #{@statement.coupon_usage_limit})."
           when "error" then " Cupom NÃO renovado: #{@statement.coupon_error}"
           when "skipped" then " Sem cupom cadastrado."
           else ""
           end
    back_with(@statement.coupon_status == "error" ? { alert: msg } : { notice: msg })
  end

  def reject
    return back_with(alert: "Mês já pago: desfaça o pagamento antes.") if @statement.paid?
    @statement.reject!(by: current_user, note: params[:note])
    back_with(notice: "#{@statement.influencer.name}: mês reprovado. Nada a pagar e cupom não renovado.")
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

  def default_month = MonthlyStatement.review_month

  def back_with(flash_opts)
    redirect_back fallback_location: reviews_path(mes: @statement.month.strftime("%Y-%m")), **flash_opts
  end

  def parse_money(value)
    v = value.to_s.strip
    return nil if v.blank?
    v = v.delete(".").tr(",", ".") if v.include?(",")
    v.to_d
  end
end
