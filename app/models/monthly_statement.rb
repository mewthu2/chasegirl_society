# Fechamento mensal de uma influenciadora: entregas aprovadas, valor a pagar, pagamento e cupom.
class MonthlyStatement < ApplicationRecord
  PAYMENT_LABELS = { "open" => "A pagar", "paid" => "Pago" }.freeze
  COUPON_LABELS = {
    "none" => "Meta não atingida", "done" => "Uso liberado", "error" => "Falha na Shopify", "skipped" => "Sem cupom"
  }.freeze

  belongs_to :influencer
  belongs_to :paid_by, class_name: "User", optional: true

  validates :month, presence: true, uniqueness: { scope: :influencer_id }

  scope :for_month, ->(month) { where(month: month.to_date.beginning_of_month) }

  def proofs = influencer.proofs.for_month(month)

  def delivered
    @delivered ||= proofs.approved.group(:kind).sum(:quantity)
  end

  def pending_counts
    @pending_counts ||= proofs.pending.group(:kind).sum(:quantity)
  end

  def delivered_for(kind) = delivered.fetch(kind.to_s, 0)
  def pending_for(kind) = pending_counts.fetch(kind.to_s, 0)
  def channel_met?(kind) = delivered_for(kind) >= influencer.goal_for(kind)

  def goal_met?
    influencer.channels.any? && influencer.channels.all? { channel_met?(_1) }
  end

  # Cada canal cumprido libera a sua fatia do cachê.
  def amount_due
    influencer.channels.select { channel_met?(_1) }.sum(0.to_d) { influencer.channel_value(_1) }
  end

  def amount_contracted = influencer.channel_values.values.sum(0.to_d)

  def progress_percent
    total = influencer.channels.sum { influencer.goal_for(_1) }
    return 0 if total.zero?
    done = influencer.channels.sum { [delivered_for(_1), influencer.goal_for(_1)].min }
    (done * 100.0 / total).round
  end

  def paid? = payment_status == "paid"
  def payment_label = PAYMENT_LABELS[payment_status]
  def coupon_label = COUPON_LABELS[coupon_status]
  def coupon_done? = coupon_status == "done"

  def mark_paid!(by:, amount: nil, note: nil)
    update!(payment_status: "paid", paid_at: Time.current, paid_by: by,
            amount_paid: amount.presence || amount_due, payment_note: note.presence || payment_note)
  end

  def mark_unpaid!
    update!(payment_status: "open", paid_at: nil, paid_by: nil, amount_paid: nil)
  end

  # Chamado sempre que uma comprovação muda de situação. Ao bater a meta do mês,
  # aumenta em 1 o limite de usos do cupom na Shopify (uma única vez por mês).
  def goal_reached!
    reload
    @delivered = @pending_counts = nil
    return unless goal_met?
    return if coupon_done?
    increment_coupon!
  end

  def increment_coupon!
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
