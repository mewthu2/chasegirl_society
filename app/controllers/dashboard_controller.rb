class DashboardController < ApplicationController
  def show
    return redirect_to portal_path unless admin?

    @influencers = Influencer.active.ordered.select { _1.active_in?(selected_month) }
    @statements = @influencers.map { _1.statement_for(selected_month) }
    @pending_proofs = Proof.pending.includes(:influencer, images_attachments: :blob).recent.limit(8)
    @pending_count = Proof.pending.count

    @goal_met = @statements.count(&:goal_met?)
    @amount_due = @statements.sum(&:amount_due)
    @amount_paid = @statements.select(&:paid?).sum { _1.amount_paid.to_d }
    @contracted = @statements.sum(&:amount_contracted)

    @channel_totals = Influencer::CHANNELS.index_with do |kind|
      list = @influencers.select { _1.goal_for(kind).positive? }
      goal = list.sum { _1.goal_for(kind) }
      done = @statements.sum { [_1.delivered_for(kind), _1.influencer.goal_for(kind)].min }
      { goal:, done: }
    end
  end
end
