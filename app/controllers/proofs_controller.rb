class ProofsController < ApplicationController
  before_action :require_admin, only: %i[approve reject reopen]
  before_action :set_proof, only: %i[show edit update destroy approve reject reopen]

  def index
    scope = admin? ? Proof.all : current_user.influencer.proofs
    @status = params[:status].presence || (admin? ? "pending" : "todas")
    scope = scope.where(status: @status) if Proof::STATUSES.include?(@status)
    scope = scope.where(kind: params[:kind]) if Influencer::CHANNELS.include?(params[:kind])
    scope = scope.for_month(selected_month) if params[:mes].present?
    scope = scope.where(influencer_id: params[:influencer_id]) if admin? && params[:influencer_id].present?
    @proofs = scope.includes(:influencer, :reviewed_by, images_attachments: :blob).recent.limit(200)
    @counts = (admin? ? Proof.all : current_user.influencer.proofs).group(:status).count
  end

  def show; end

  def new
    @proof = Proof.new(influencer: default_influencer, kind: params[:kind].presence || "stories",
                       posted_on: Date.current)
  end

  def create
    @proof = Proof.new(proof_params)
    @proof.influencer = admin? ? Influencer.find_by(id: params.dig(:proof, :influencer_id)) : current_user.influencer
    @proof.submitted_by = current_user
    if @proof.save
      @proof.approve!(by: current_user) if admin? && params[:approve_now] == "1"
      redirect_to after_save_path, notice: "Comprovação enviada! A equipe Chase vai conferir."
    elsif params[:return_to] == "portal"
      redirect_to portal_path(influencer_id: (@proof.influencer_id if admin?), mes: params[:mes], kind: @proof.kind, anchor: "comprovar"),
                  alert: "Não enviada: #{@proof.errors.full_messages.to_sentence}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to @proof, alert: "Só é possível editar comprovações em análise." unless editable?
  end

  def update
    return redirect_to(@proof, alert: "Só é possível editar comprovações em análise.") unless editable?

    @proof.images.attach(params[:proof][:images].compact_blank) if params.dig(:proof, :images).present?
    if @proof.update(proof_params.except(:images))
      redirect_to @proof, notice: "Comprovação atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    return redirect_to(@proof, alert: "Comprovação já analisada não pode ser apagada.") unless editable?

    month = @proof.month
    influencer = @proof.influencer
    @proof.destroy
    influencer.statement_for(month).goal_reached!
    redirect_to admin? ? proofs_path : portal_path, notice: "Comprovação apagada."
  end

  def approve
    @proof.approve!(by: current_user)
    redirect_back fallback_location: proofs_path, notice: approval_notice
  end

  def reject
    @proof.reject!(by: current_user, note: params[:review_note].presence || "Comprovação não aceita")
    redirect_back fallback_location: proofs_path, notice: "Comprovação recusada."
  end

  def reopen
    @proof.reopen!(by: current_user)
    redirect_back fallback_location: proofs_path, notice: "Comprovação voltou para análise."
  end

  private

  def set_proof
    @proof = admin? ? Proof.find(params[:id]) : current_user.influencer.proofs.find(params[:id])
  end

  def editable? = admin? || @proof.pending?

  def default_influencer
    admin? ? Influencer.find_by(id: params[:influencer_id]) : current_user.influencer
  end

  def proof_params
    params.require(:proof).permit(:kind, :quantity, :posted_on, :month, :link, :description, images: [])
  end

  def after_save_path
    mes = @proof.month.strftime("%Y-%m")
    return portal_path(mes:) unless admin?
    case params[:return_to]
    when "portal" then portal_path(influencer_id: @proof.influencer_id, mes:)
    when "influencer" then influencer_path(@proof.influencer)
    else proofs_path
    end
  end

  def approval_notice
    statement = @proof.influencer.statement_for(@proof.month)
    msg = "Comprovação aprovada."
    if statement.goal_met?
      msg += case statement.coupon_status
             when "done" then " Meta do mês batida — cupom #{@proof.influencer.coupon_code} liberado (+1 uso)."
             when "error" then " Meta batida, mas a Shopify falhou: #{statement.coupon_error}"
             else ""
             end
    end
    msg
  end
end
