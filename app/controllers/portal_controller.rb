class PortalController < ApplicationController
  before_action :load_influencer

  def show
    @statement = @influencer.statement_for(selected_month)
    @proofs = @influencer.proofs.for_month(selected_month).includes(images_attachments: :blob).recent
    @history = @influencer.monthly_statements.where.not(month: selected_month).order(month: :desc).limit(6)
  end

  private

  def load_influencer
    if admin?
      @influencer = Influencer.find_by(id: params[:influencer_id])
      redirect_to influencers_path, notice: "Escolha uma influenciadora para ver a área dela." unless @influencer
    else
      @influencer = current_user.influencer
    end
  end
end
