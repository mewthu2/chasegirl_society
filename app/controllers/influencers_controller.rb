class InfluencersController < ApplicationController
  before_action :require_staff
  before_action :require_manager, only: %i[new create]
  before_action :set_influencer, except: %i[index new create]

  # Metas, valores, cupom e vigência: só o perfil Gerente configura.
  CONTRACT_FIELDS = %i[feed_goal stories_goal tiktok_goal cash_value permuta_value cash_is_permuta coupon_code starts_on ends_on].freeze
  PROFILE_FIELDS = %i[name instagram tiktok city followers pix_key phone notes active].freeze

  def index
    scope = Influencer.ordered.includes(:user)
    scope = scope.where(active: params[:status] != "inativas") unless params[:status] == "todas"
    if params[:q].present?
      q = "%#{Influencer.sanitize_sql_like(params[:q].strip.delete_prefix('@'))}%"
      scope = scope.where("name ILIKE :q OR instagram ILIKE :q OR tiktok ILIKE :q OR coupon_code ILIKE :q", q:)
    end
    @influencers = scope
    @statements = MonthlyStatement.for_month(selected_month).where(influencer: @influencers).index_by(&:influencer_id)
  end

  def show
    @statement = @influencer.statement_for(selected_month)
    @proofs = @influencer.proofs.includes(images_attachments: :blob).recent.limit(30)
    @statements = @influencer.monthly_statements.order(month: :desc)
  end

  def new
    @influencer = Influencer.new(feed_goal: 1, stories_goal: 4, tiktok_goal: 1, cash_value: 1000, permuta_value: 1500,
                                 starts_on: Date.current, ends_on: 3.months.from_now.to_date)
  end

  def create
    @influencer = Influencer.new(influencer_params)
    if @influencer.save
      redirect_to @influencer, notice: "Influenciadora cadastrada. Agora crie o acesso dela."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @influencer.update(influencer_params)
      redirect_to @influencer, notice: "Cadastro atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Desligar: só a equipe (a influenciadora nunca vê esta tela). Ela perde o acesso na hora; o histórico fica.
  def destroy
    @influencer.deactivate!
    redirect_to @influencer, notice: "#{@influencer.name} foi desligada: perdeu o acesso agora. O histórico continua guardado."
  end

  def reactivate
    @influencer.reactivate!
    redirect_to @influencer, notice: "#{@influencer.name} foi reativada. Ela já pode entrar de novo com a mesma senha."
  end

  # Pré-cadastro: a equipe informa só o e-mail; ela recebe o convite e cria a própria senha.
  def save_access
    email = params.require(:access).permit(:email_address)[:email_address]
    user = User.invite(influencer: @influencer, email:)
    email_changed = user.new_record? || user.will_save_change_to_email_address?

    unless user.save
      return redirect_to @influencer, alert: "Não foi possível salvar: #{user.errors.full_messages.to_sentence}"
    end

    if user.invitation_pending? && email_changed
      deliver_invitation(user)
    else
      redirect_to @influencer, notice: "E-mail de acesso atualizado para #{user.email_address}."
    end
  end

  def resend_invitation
    user = @influencer.user or return redirect_to(@influencer, alert: "Cadastre o e-mail antes.")
    if user.activated?
      PasswordsMailer.reset(user).deliver_now
      redirect_to @influencer, notice: "Link para redefinir a senha enviado para #{user.email_address} (vale 15 minutos)."
    else
      deliver_invitation(user)
    end
  rescue StandardError => e
    Rails.logger.error("[InfluencerMailer] #{e.class}: #{e.message}")
    redirect_to @influencer, alert: "Não foi possível enviar o e-mail: #{e.message}"
  end

  def revoke_access
    @influencer.user&.destroy
    redirect_to @influencer, notice: "Acesso removido."
  end

  def coupon
    @coupon = ShopifyCoupon.new(@influencer.coupon_code).lookup
    redirect_to @influencer, notice: "Cupom #{@influencer.coupon_code}: limite de usos #{@coupon[:usage_limit] || 'ilimitado'} · usado #{@coupon[:used]} vez(es) · #{@coupon[:status]}"
  rescue ShopifyCoupon::Error => e
    redirect_to @influencer, alert: e.message
  end

  private

  def deliver_invitation(user)
    InfluencerMailer.invitation(user).deliver_now
    user.update_columns(invited_at: Time.current, access_sent_at: Time.current)
    redirect_to @influencer, notice: "Convite enviado para #{user.email_address}. Ela cria a senha pelo link (vale 7 dias)."
  rescue StandardError => e
    Rails.logger.error("[InfluencerMailer] #{e.class}: #{e.message}")
    redirect_to @influencer, alert: "Acesso salvo, mas o convite não foi enviado (#{e.message}). Tente \"Reenviar convite\"."
  end

  def set_influencer = @influencer = Influencer.find(params[:id])

  def influencer_params
    allowed = PROFILE_FIELDS + (current_user.can_configure_contracts? ? CONTRACT_FIELDS : [])
    params.require(:influencer).permit(*allowed)
  end
end
