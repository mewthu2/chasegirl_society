class User < ApplicationRecord
  # admin: vê e faz tudo (inclui pagar). manager (Gerente): vê tudo, configura metas/valores,
  # no financeiro só vê o "A pagar". influencer (Usuário): só a própria área.
  ROLES = %w[admin manager influencer].freeze
  ROLE_LABELS = { "admin" => "Admin", "manager" => "Gerente", "influencer" => "Usuário (influenciadora)" }.freeze
  STAFF_ROLES = %w[admin manager].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :influencer, optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :influencer, presence: true, if: :influencer?
  validates :password, length: { minimum: 6 }, allow_nil: true

  scope :staff, -> { where(role: STAFF_ROLES) }

  def admin? = role == "admin"
  def manager? = role == "manager"
  def staff? = STAFF_ROLES.include?(role)
  def influencer? = role == "influencer"
  def role_label = ROLE_LABELS[role]

  # Permissões
  def can_configure_contracts? = manager?
  def can_review? = staff?
  def can_pay? = admin?
  def can_manage_team? = admin?

  def display_name
    name.presence || influencer&.name || email_address
  end

  def initials
    display_name.split(/[\s@.]+/).reject(&:blank?).first(2).map { _1[0] }.join.upcase
  end
end
