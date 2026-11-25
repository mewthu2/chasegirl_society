class Proof < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze
  STATUS_LABELS = { "pending" => "Em análise", "approved" => "Aprovada", "rejected" => "Recusada" }.freeze
  MAX_IMAGES = 15
  # O que cada canal exige: Feed = link; Stories = print (story não tem link); TikTok = link e print.
  LINK_KINDS = %w[feed tiktok].freeze
  PHOTO_KINDS = %w[stories tiktok].freeze
  KIND_HINTS = { "feed" => "Post no feed ou Reels · link", "stories" => "Um story por envio · print",
                 "tiktok" => "Vídeo no TikTok · link e print" }.freeze

  belongs_to :influencer
  belongs_to :submitted_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many_attached :images

  before_validation :normalize_month

  validates :kind, inclusion: { in: Influencer::CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :month, presence: true
  validates :link, presence: { message: "da publicação é obrigatório" }, if: :needs_link?
  validates :link, format: { with: %r{\Ahttps?://}i, message: "precisa começar com http:// ou https://" }, allow_blank: true
  validate :evidence_present
  validate :images_are_valid
  validate :channel_contracted
  validate :month_open, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :for_month, ->(month) { where(month: month.to_date.beginning_of_month) }
  scope :recent, -> { order(created_at: :desc) }

  def pending? = status == "pending"
  def approved? = status == "approved"
  def rejected? = status == "rejected"
  def status_label = STATUS_LABELS[status]
  def kind_label = Influencer.channel_label(kind)
  def needs_link? = LINK_KINDS.include?(kind)
  def needs_photo? = PHOTO_KINDS.include?(kind)

  # Meses em que dá para enviar: o atual e o anterior (enquanto não foi aprovado na conferência).
  def self.month_options(influencer, today: Date.current)
    current = today.beginning_of_month
    [current.prev_month, current].reject { |m| influencer && month_closed?(influencer, m) }
  end

  def self.month_closed?(influencer, month)
    influencer.monthly_statements.find_by(month: month.to_date.beginning_of_month)&.approved? || false
  end

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
    self.link = nil if kind == "stories"
    self.link = link.to_s.strip.presence && (link.strip.match?(%r{\Ahttps?://}i) ? link.strip : "https://#{link.strip}")
    # Cada envio é UMA tarefa (1 story, 1 post, 1 TikTok), com quantas fotos forem precisas.
    self.quantity = 1
    self.month = (month || posted_on || Date.current).to_date.beginning_of_month
  end

  def evidence_present
    errors.add(:images, "envie pelo menos uma foto/print da publicação") if needs_photo? && !images.attached?
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

  def month_open
    return unless influencer && month
    if month > Date.current.beginning_of_month
      errors.add(:base, "O mês de referência não pode ser um mês futuro")
    elsif self.class.month_closed?(influencer, month)
      errors.add(:base, "Esse mês já foi aprovado na conferência; escolha outro mês")
    end
  end

  def channel_contracted
    return unless influencer && kind
    errors.add(:kind, "não está no contrato desta influenciadora") unless influencer.channels.include?(kind)
  end
end
