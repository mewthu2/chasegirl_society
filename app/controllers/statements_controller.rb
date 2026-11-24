require "csv"

# Financeiro. "A pagar" (Admin e Gerente) = meses aprovados ainda não pagos.
# "Pagos" e registrar pagamento: só Admin.
class StatementsController < ApplicationController
  before_action :require_staff
  before_action :require_admin, only: %i[paid pay unpay]
  before_action :set_statement, only: %i[pay unpay]

  def index
    @statements = MonthlyStatement.payable.includes(:influencer, :reviewed_by).order(:due_on, :month).to_a
    @statements.select! { _1.month == selected_month } if params[:mes].present?
    respond_to do |format|
      format.html
      format.csv { send_data to_csv(@statements), filename: "a-pagar-#{Date.current.strftime('%Y-%m-%d')}.csv" }
    end
  end

  def paid
    @statements = MonthlyStatement.paid.includes(:influencer, :paid_by).order(paid_at: :desc).limit(300)
  end

  def pay
    amount = params[:amount].to_s.strip.presence
    amount = amount.delete(".").tr(",", ".").to_d if amount&.include?(",")
    @statement.mark_paid!(by: current_user, amount: amount&.to_d, note: params[:note])
    redirect_back fallback_location: statements_path, notice: "Pagamento de #{@statement.influencer.name} registrado."
  end

  def unpay
    @statement.mark_unpaid!
    redirect_back fallback_location: paid_statements_path, notice: "Pagamento desfeito: voltou para o A pagar."
  end

  private

  def set_statement = @statement = MonthlyStatement.find(params[:id])

  def to_csv(statements)
    CSV.generate(col_sep: ";") do |csv|
      csv << ["Influenciadora", "Instagram", "Chave PIX", "Competência", "Vencimento", "Valor a pagar", "Aprovado por", "Aprovado em"]
      statements.each do |s|
        i = s.influencer
        csv << [i.name, i.instagram, i.pix_key, s.month.strftime("%m/%Y"), s.due_on&.strftime("%d/%m/%Y"),
                s.amount_payable.to_s("F").tr(".", ","), s.reviewed_by&.display_name, s.reviewed_at&.strftime("%d/%m/%Y")]
      end
    end
  end
end
