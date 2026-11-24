# Fechamento mensal de uma influenciadora.
#
# Ciclo: as entregas são do mês M. De 1 a 10 do mês M+1 a equipe faz a conferência;
# o pagamento é no dia 10. Aprovar o mês renova o cupom (+1 uso na Shopify) e cria o
# "a pagar" do combinado, com vencimento no dia 10.
class MonthlyStatement < ApplicationRecord
  REVIEW_DAYS = 10
  REVIEW_LABELS = { "open" => "Aguardando conferência", "approved" => "Aprovado", "rejected" => "Reprovado" }.freeze
  PAYMENT_LABELS = { "open" => "A pagar", "paid" => "Pago" }.freeze
  COUPON_LABELS = {
    "none" => "Não renovado", "done" => "Renovado (+1 uso)", "error" => "Falha na Shopify", "skipped" => "Sem cupom"
  }.freeze

  belongs_to :influencer
  belongs_to :paid_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :month, presence: true, uniqueness: { scope: :influencer_id }
  validates :amount_payable, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_month, ->(month) { where(month: month.to_date.beginning_of_month) }
  scope :approved, -> { where(review_status: "approved") }
  scope :payable, -> { approved.where(payment_status: "open").where("amount_payable > 0") }
  scope :paid, -> { where(payment_status: "paid") }

  # ---- Calendário -----------------------------------------------------------

  def self.review_start(month) = month.to_date.beginning_of_month.next_month
  def self.due_date(month) = review_start(month) + (REVIEW_DAYS - 1)

  # Mês que está (ou acabou de estar) em conferência: sempre o mês anterior ao atual.
  def self.review_month(today = Date.current) = today.beginning_of_month.prev_month

  # Influenciadoras ativas no mês que ainda não foram aprovadas nem reprovadas.
  def self.awaiting_review_count(month)
    month = month.to_date.beginning_of_month
    active_ids = Influencer.active.select { _1.active_in?(month) }.map(&:id)
    decided = for_month(month).where.not(review_status: "open").pluck(:influencer_id)
    (active_ids - decided).size
  end

  def self.phase(month, today = Date.current)
    month = month.to_date.beginning_of_month
    return :running if today <= month.end_of_month
    return :review if today <= due_date(month)
    :closed
  end

  def review_start = self.class.review_start(month)
  def due_date = self.class.due_date(month)
  def phase(today = Date.current) = self.class.phase(month, today)

  # ---- Entregas ---------------------------------------------------------------

  def proofs = influencer.proofs.for_month(month)

  def delivered
    @delivered ||= proofs.approved.group(:kind).sum(:quantity)
  end

  def pending_counts
    @pending_counts ||= proofs.pending.group(:kind).sum(:quantity)
  end

  def delivered_for(kind) = delivered.fetch(kind.to_s, 0)
  def pending_for(kind) = pending_counts.fetch(kind.to_s, 0)
  def pending_total = pending_counts.values.sum
  def channel_met?(kind) = delivered_for(kind) >= influencer.goal_for(kind)

  def goal_met?
    influencer.channels.any? && influencer.channels.all? { channel_met?(_1) }
  end

  # Sugestão de valor: cada canal cumprido libera a sua fatia do combinado.
  def amount_due
    influencer.channels.select { channel_met?(_1) }.sum(0.to_d) { influencer.channel_value(_1) }
  end

  def amount_contracted = influencer.channel_values.values.sum(0.to_d)

  # Valor que vale para o financeiro: o definido na aprovação.
  def amount_to_pay = approved? ? amount_payable.to_d : 0.to_d

  def progress_percent
    total = influencer.channels.sum { influencer.goal_for(_1) }
    return 0 if total.zero?
    done = influencer.channels.sum { [delivered_for(_1), influencer.goal_for(_1)].min }
    (done * 100.0 / total).round
  end

  # ---- Conferência ------------------------------------------------------------

  def approved? = review_status == "approved"
  def rejected? = review_status == "rejected"
  def review_open? = review_status == "open"
  def review_label = REVIEW_LABELS[review_status]

  def approve!(by:, amount: nil, renew_coupon: true, note: nil)
    raise ActiveRecord::RecordInvalid, self if paid?

    update!(review_status: "approved", reviewed_by: by, reviewed_at: Time.current, review_note: note.presence,
            amount_payable: amount.nil? ? amount_due : amount.to_d, due_on: due_date, payment_status: "open")
    increment_coupon! if renew_coupon
  end

  def reject!(by:, note: nil)
    update!(review_status: "rejected", reviewed_by: by, reviewed_at: Time.current, review_note: note.presence,
            amount_payable: nil, due_on: nil)
  end

  # Volta para conferência. O uso já liberado no cupom não é desfeito na Shopify.
  def reopen!
    update!(review_status: "open", reviewed_by: nil, reviewed_at: nil, amount_payable: nil, due_on: nil)
  end

  # ---- Pagamento ----------------------------------------------------------------

  def paid? = payment_status == "paid"
  def payment_label = approved? ? PAYMENT_LABELS[payment_status] : "—"

  def mark_paid!(by:, amount: nil, note: nil)
    update!(payment_status: "paid", paid_at: Time.current, paid_by: by,
            amount_paid: amount.presence || amount_payable, payment_note: note.presence || payment_note)
  end

  def mark_unpaid!
    update!(payment_status: "open", paid_at: nil, paid_by: nil, amount_paid: nil)
  end

  # ---- Cupom ----------------------------------------------------------------------

  def coupon_label = COUPON_LABELS[coupon_status]
  def coupon_done? = coupon_status == "done"

  # +1 no limite de usos do cupom na Shopify — uma única vez por mês.
  def increment_coupon!
    return if coupon_done?
    if influencer.coupon_code.blank?
      update!(coupon_status: "skipped", coupon_error: "Influenciadora sem cupom cadastrado")
      return
    end

    with_lock do
      return if coupon_done?
      new_limit = ShopifyCoupon.new(influencer.coupon_code).increment_usage_limit!
      update!(coupon_status: "done", coupon_usage_limit: new_limit, coupon_incremented_at: Time.current, coupon_error: nil)
    end
  rescue ShopifyCoupon::Error => e
    update!(coupon_status: "error", coupon_error: e.message)
  end
end
