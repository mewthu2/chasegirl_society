class InfluencersController < ApplicationController
  before_action :require_admin
  before_action :set_influencer, except: %i[index new create]

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

  def destroy
    @influencer.update!(active: false)
    redirect_to influencers_path, notice: "#{@influencer.name} foi desativada (histórico preservado)."
  end

  def save_access
    user = @influencer.user || @influencer.build_user(role: "influencer")
    attrs = params.require(:access).permit(:email_address, :password)
    attrs.delete(:password) if attrs[:password].blank? && user.persisted?
    user.assign_attributes(attrs.merge(name: @influencer.name, role: "influencer"))
    if user.save
      user.sessions.destroy_all if attrs[:password].present? && user.previously_new_record? == false
      redirect_to @influencer, notice: "Acesso salvo para #{user.email_address}."
    else
      redirect_to @influencer, alert: "Não foi possível salvar o acesso: #{user.errors.full_messages.to_sentence}"
    end
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

  def set_influencer = @influencer = Influencer.find(params[:id])

  def influencer_params
    params.require(:influencer).permit(:name, :instagram, :tiktok, :city, :followers, :coupon_code,
      :feed_goal, :stories_goal, :tiktok_goal, :cash_value, :permuta_value, :cash_is_permuta,
      :starts_on, :ends_on, :pix_key, :phone, :notes, :active)
  end
end
