class Influencer < ApplicationRecord
  CHANNELS = %w[feed stories tiktok].freeze
  CHANNEL_LABELS = { "feed" => "Feed/Reels", "stories" => "Stories", "tiktok" => "TikTok" }.freeze

  has_one :user, dependent: :destroy
  has_many :proofs, dependent: :destroy
  has_many :monthly_statements, dependent: :destroy

  normalizes :instagram, with: ->(v) { v.to_s.strip.delete_prefix("@").downcase.presence }
  normalizes :tiktok, with: ->(v) { v.to_s.strip.delete_prefix("@").presence }
  normalizes :coupon_code, with: ->(v) { v.to_s.strip.upcase.presence }

  PIX_KEY_TYPES = { "cpf" => "CPF", "cnpj" => "CNPJ", "email" => "E-mail", "phone" => "Telefone", "random" => "Chave aleatória" }.freeze

  validates :name, presence: true
  validates :pix_key_type, inclusion: { in: PIX_KEY_TYPES.keys, message: "escolha o tipo da chave PIX" }, allow_blank: true
  validates :pix_key_type, presence: { message: "informe o tipo da chave PIX" }, if: -> { pix_key.present? && will_save_change_to_pix_key? }
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

  def pix_key_type_label = PIX_KEY_TYPES[pix_key_type]

  # Tipo pela cara da chave, só quando não há dúvida (11 dígitos soltos pode ser CPF ou celular).
  def self.guess_pix_key_type(key)
    key = key.to_s.strip
    if key.include?("@") then "email"
    elsif key.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/) then "random"
    elsif key.match?(/\A\d{3}\.\d{3}\.\d{3}-\d{2}\z/) then "cpf"
    elsif key.match?(%r{\A\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}\z}) then "cnpj"
    elsif key.start_with?("+") || key.match?(/\A\(\d{2}\)/) then "phone"
    end
  end

  # "CPF · 123.456.789-00" (ou só a chave, se o tipo não foi informado)
  def pix_label
    return nil if pix_key.blank?
    [pix_key_type_label, pix_key].compact.join(" · ")
  end

  # Cupom padrão: CG + @ do Instagram (ex.: @palomaleuze → CGPALOMALEUZE).
  def default_coupon_code = instagram.present? ? "CG#{instagram.upcase}" : nil

  # Garante o cupom na Shopify: se ainda não tem código, usa o padrão; cria com 1 uso no valor
  # da permuta (se já existir lá, não mexe). Falha na Shopify não impede o cadastro: fica no log.
  # => :created | :exists | nil
  def ensure_coupon!
    if coupon_code.blank?
      code = default_coupon_code
      return nil if code.blank? || self.class.where.not(id:).exists?(coupon_code: code)
      update!(coupon_code: code)
    end
    ShopifyCoupon.new(coupon_code).create!(amount: permuta_value)
  rescue ShopifyCoupon::Error => e
    Rails.logger.error("[Cupom] #{name} (#{coupon_code}): #{e.message}")
    nil
  end

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
