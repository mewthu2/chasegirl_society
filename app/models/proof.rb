class Proof < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze
  STATUS_LABELS = { "pending" => "Em análise", "approved" => "Aprovada", "rejected" => "Recusada" }.freeze
  MAX_IMAGES = 10

  belongs_to :influencer
  belongs_to :submitted_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many_attached :images

  before_validation :normalize_month

  validates :kind, inclusion: { in: Influencer::CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :month, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 30 }
  validates :link, presence: { message: "da publicação é obrigatório" }
  validates :link, format: { with: %r{\Ahttps?://}i, message: "precisa começar com http:// ou https://" }, allow_blank: true
  validate :evidence_present
  validate :images_are_valid
  validate :channel_contracted

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :for_month, ->(month) { where(month: month.to_date.beginning_of_month) }
  scope :recent, -> { order(created_at: :desc) }

  def pending? = status == "pending"
  def approved? = status == "approved"
  def rejected? = status == "rejected"
  def status_label = STATUS_LABELS[status]
  def kind_label = Influencer.channel_label(kind)

  def approve!(by:)
    review!("approved", by:, note: nil)
  end

  def reject!(by:, note:)
    review!("rejected", by:, note:)
  end

  def reopen!(by:)
    review!("pending", by:, note: nil)
  end

  private

  def review!(new_status, by:, note:)
    update!(status: new_status, reviewed_by: new_status == "pending" ? nil : by,
            reviewed_at: new_status == "pending" ? nil : Time.current, review_note: note)
  end

  def normalize_month
    self.link = link.to_s.strip.presence && (link.strip.match?(%r{\Ahttps?://}i) ? link.strip : "https://#{link.strip}")
    # Sem quantidade informada: em Stories conta 1 por foto enviada; nos demais, 1.
    self.quantity = (kind == "stories" && images.attached? ? [images.size, 1].max : 1) if quantity.blank?
    self.month = (month || posted_on || Date.current).to_date.beginning_of_month
  end

  def evidence_present
    errors.add(:images, "envie pelo menos uma foto/print da publicação") unless images.attached?
  end

  def images_are_valid
    return unless images.attached?
    errors.add(:images, "máximo de #{MAX_IMAGES} arquivos por envio") if images.size > MAX_IMAGES
    images.each do |img|
      unless img.content_type.to_s.start_with?("image/", "video/")
        errors.add(:images, "#{img.filename} não é imagem nem vídeo")
      end
      errors.add(:images, "#{img.filename} passa de 25 MB") if img.byte_size.to_i > 25.megabytes
    end
  end

  def channel_contracted
    return unless influencer && kind
    errors.add(:kind, "não está no contrato desta influenciadora") unless influencer.channels.include?(kind)
  end
end
