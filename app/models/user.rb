class User < ApplicationRecord
  # admin: vê e faz tudo (inclui pagar). manager (Gerente): vê tudo, configura metas/valores,
  # no financeiro só vê o "A pagar". influencer (Usuário): só a própria área.
  ROLES = %w[admin manager influencer].freeze
  ROLE_LABELS = { "admin" => "Admin", "manager" => "Gerente", "influencer" => "Usuário (influenciadora)" }.freeze
  STAFF_ROLES = %w[admin manager].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :influencer, optional: true

  # Convite (pré-cadastro): link para a influenciadora criar a senha. Vale 7 dias e
  # deixa de valer assim que ela conclui o cadastro (activated_at muda).
  INVITATION_TTL = 7.days
  generates_token_for :invitation, expires_in: INVITATION_TTL do
    activated_at.to_i
  end

  # Primeiro acesso pelo @: ela informa e-mail e senha; a conta só ativa ao clicar no link
  # enviado para esse e-mail. O token muda se ela refizer o primeiro acesso com outro e-mail.
  CONFIRMATION_TTL = 2.days
  generates_token_for :email_confirmation, expires_in: CONFIRMATION_TTL do
    [activated_at.to_i, email_address]
  end

  # Login por e-mail ou pelo @ do Instagram (influenciadoras).
  def self.find_by_login(login)
    value = login.to_s.strip.downcase
    return nil if value.blank?
    return find_by(email_address: value) if value.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    Influencer.find_by_handle(value)&.user
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :influencer, presence: true, if: :influencer?
  validates :password, length: { minimum: 6 }, allow_nil: true

  scope :staff, -> { where(role: STAFF_ROLES) }

  # Concluiu o cadastro (convite, primeiro acesso pelo @ ou primeira senha): gera o cupom dela.
  after_commit :create_influencer_coupon, on: %i[create update], if: -> { influencer? && saved_change_to_activated_at?(from: nil) }

  def admin? = role == "admin"
  def manager? = role == "manager"
  def staff? = STAFF_ROLES.include?(role)
  def influencer? = role == "influencer"
  # Influenciadora desligada (parceria inativa) não entra; a equipe sempre entra.
  def access_blocked? = influencer? && !influencer&.active?
  def role_label = ROLE_LABELS[role]

  # Permissões
  def can_configure_contracts? = staff?
  def can_review? = staff?
  def can_pay? = admin?
  def can_manage_team? = admin?

  def activated? = activated_at.present?
  def invitation_pending? = !activated?

  # Cria o usuário com uma senha aleatória que ninguém conhece; ela define a própria pelo convite.
  def self.invite(influencer:, email:)
    user = influencer.user || influencer.build_user(role: "influencer")
    user.assign_attributes(email_address: email, name: influencer.name, role: "influencer")
    user.password = SecureRandom.base58(32) if user.new_record?
    user
  end

  def activate!(password:, password_confirmation:)
    self.password = password
    self.password_confirmation = password_confirmation
    errors.add(:password, "precisa ter pelo menos 6 caracteres") if password.to_s.length < 6
    return false if errors.any?
    self.activated_at = Time.current
    save
  end

  def display_name
    name.presence || influencer&.name || email_address
  end

  def initials
    display_name.split(/[\s@.]+/).reject(&:blank?).first(2).map { _1[0] }.join.upcase
  end

  private

  def create_influencer_coupon
    influencer&.ensure_coupon!
  end
end
