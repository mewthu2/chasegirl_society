class User < ApplicationRecord
  ROLES = %w[admin influencer].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :influencer, optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :influencer, presence: true, if: :influencer?
  validates :password, length: { minimum: 6 }, allow_nil: true

  scope :admins, -> { where(role: "admin") }

  def admin? = role == "admin"
  def influencer? = role == "influencer"

  def display_name
    name.presence || influencer&.name || email_address
  end

  def initials
    display_name.split(/[\s@.]+/).reject(&:blank?).first(2).map { _1[0] }.join.upcase
  end
end
