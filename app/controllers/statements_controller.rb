require "csv"

# Módulo financeiro: o que pagar para cada influenciadora no mês de competência.
class StatementsController < ApplicationController
  before_action :require_admin
  before_action :set_statement, only: %i[show pay unpay coupon]

  def index
    influencers = Influencer.ordered.select { _1.active_in?(selected_month) || _1.monthly_statements.for_month(selected_month).exists? }
    @statements = influencers.map { _1.statement_for(selected_month) }
    @filter = params[:filtro].presence || "todas"
    @statements = case @filter
                  when "a_pagar" then @statements.select { !_1.paid? && _1.amount_due.positive? }
                  when "pagas" then @statements.select(&:paid?)
                  when "sem_entrega" then @statements.select { _1.amount_due.zero? }
                  else @statements
                  end

    respond_to do |format|
      format.html
      format.csv { send_data to_csv(@statements), filename: "a-pagar-#{selected_month.strftime('%Y-%m')}.csv" }
    end
  end

  def show
    @proofs = @statement.proofs.includes(images_attachments: :blob).recent
  end

  def pay
    amount = params[:amount].to_s.tr(".", "").tr(",", ".").presence
    @statement.mark_paid!(by: current_user, amount: amount&.to_d, note: params[:note])
    redirect_back fallback_location: statements_path(mes: month_param), notice: "Pagamento de #{@statement.influencer.name} registrado."
  end

  def unpay
    @statement.mark_unpaid!
    redirect_back fallback_location: statements_path(mes: month_param), notice: "Pagamento desfeito."
  end

  def coupon
    @statement.increment_coupon! if @statement.goal_met?
    if @statement.coupon_done?
      redirect_back fallback_location: statements_path(mes: month_param), notice: "Cupom liberado: novo limite #{@statement.coupon_usage_limit}."
    else
      redirect_back fallback_location: statements_path(mes: month_param), alert: @statement.coupon_error || "Meta do mês ainda não foi atingida."
    end
  end

  private

  def set_statement = @statement = MonthlyStatement.find(params[:id])
  def month_param = @statement.month.strftime("%Y-%m")

  def to_csv(statements)
    CSV.generate(col_sep: ";") do |csv|
      csv << ["Influenciadora", "Instagram", "Chave PIX", "Cachê contratado", *Influencer::CHANNELS.map { "#{Influencer.channel_label(_1)} (entregue/meta)" }, "Valor a pagar", "Situação", "Valor pago", "Pago em", "Cupom", "Cupom liberado"]
      statements.each do |s|
        i = s.influencer
        csv << [i.name, i.instagram, i.pix_key, s.amount_contracted.to_s("F"),
                *Influencer::CHANNELS.map { i.goal_for(_1).positive? ? "#{s.delivered_for(_1)}/#{i.goal_for(_1)}" : "-" },
                s.amount_due.to_s("F"), s.payment_label, s.amount_paid&.to_s("F"), s.paid_at&.strftime("%d/%m/%Y"),
                i.coupon_code, s.coupon_done? ? "sim" : "não"]
      end
    end
  end
end
