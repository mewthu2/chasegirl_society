class Influencer < ApplicationRecord
  CHANNELS = %w[feed stories tiktok].freeze
  CHANNEL_LABELS = { "feed" => "Feed/Reels", "stories" => "Stories", "tiktok" => "TikTok" }.freeze

  has_one :user, dependent: :destroy
  has_many :proofs, dependent: :destroy
  has_many :monthly_statements, dependent: :destroy

  normalizes :instagram, with: ->(v) { v.to_s.strip.delete_prefix("@").downcase.presence }
  normalizes :tiktok, with: ->(v) { v.to_s.strip.delete_prefix("@").presence }
  normalizes :coupon_code, with: ->(v) { v.to_s.strip.upcase.presence }

  validates :name, presence: true
  validates :coupon_code, uniqueness: true, allow_nil: true
  validates :instagram, uniqueness: { case_sensitive: false, message: "já está cadastrado em outra influenciadora" }, allow_nil: true
  validates :instagram, format: { with: /\A[a-z0-9._]+\z/, message: "deve ter só letras, números, ponto e _" }, allow_nil: true
  validates :feed_goal, :stories_goal, :tiktok_goal, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cash_value, :permuta_value, numericality: { greater_than_or_equal_to: 0 }
  validate :at_least_one_channel
  # Desligada (pelo botão ou pelo "Parceria ativa" do cadastro): sai na hora de qualquer sessão aberta.
  after_update_commit :end_sessions, if: -> { saved_change_to_active?(to: false) }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def self.channel_label(kind) = CHANNEL_LABELS.fetch(kind.to_s, kind.to_s)

  def goal_for(kind) = public_send("#{kind}_goal").to_i

  # Canais contratados = canais com meta > 0. O cachê é dividido igualmente entre eles:
  # feed + stories + tiktok = 33,33% cada; sem TikTok = 50% cada.
  def channels = CHANNELS.select { goal_for(_1).positive? }

  def share_percent(kind)
    return 0 unless channels.include?(kind.to_s)
    (100.0 / channels.size).round(2)
  end

  # Valor em R$ de cada canal. A sobra de centavos fica no último canal para a soma bater exatamente.
  def channel_values
    @channel_values ||= begin
      list = channels
      return {} if list.empty?
      total = cash_is_permuta? ? 0.to_d : cash_value.to_d
      base = (total / list.size).floor(2)
      values = list.index_with { base }
      values[list.last] += total - base * list.size
      values
    end
  end

  def channel_value(kind) = channel_values.fetch(kind.to_s, 0.to_d)

  def self.find_by_handle(handle)
    h = handle.to_s.strip.delete_prefix("@").downcase
    h.present? ? find_by(instagram: h) : nil
  end

  def statement_for(month)
    monthly_statements.find_or_create_by!(month: month.to_date.beginning_of_month)
  rescue ActiveRecord::RecordNotUnique
    monthly_statements.find_by!(month: month.to_date.beginning_of_month)
  end

  def active_in?(month)
    month = month.to_date.beginning_of_month
    # Sem vigência: a meta é por mês, enquanto a parceria estiver ativa (a partir do mês do cadastro).
    active? && (created_at.nil? || created_at.to_date.beginning_of_month <= month)
  end

  def instagram_url = instagram && "https://instagram.com/#{instagram}"
  def tiktok_url = tiktok && "https://tiktok.com/@#{tiktok}"

  def initials = name.split.first(2).map { _1[0] }.join.upcase

  def reset_channel_cache! = @channel_values = nil

  # Desligar: perde o acesso à área dela na hora; metas, comprovações e histórico ficam guardados.
  def deactivate! = update!(active: false)
  def reactivate! = update!(active: true)

  private

  def end_sessions
    user&.sessions&.destroy_all
  end

  def at_least_one_channel
    errors.add(:base, "Defina a meta de pelo menos um canal (Feed, Stories ou TikTok)") if channels.empty?
  end
end
