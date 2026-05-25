module Channels::Admin
  class ProjectsController < BaseController
    has_scope :by_id, :pg_search, :user_name_contains, :order_by, :with_state
    has_scope :between_created_at, using: [ :start_at, :ends_at ], allow_blank: true

    before_action do
      @total_projects =  channel.projects.size
    end

    [:approve, :launch, :reject, :push_to_draft, :cancel, :push_to_request_funds, :push_to_fraud_suspiscion, :push_to_paid].each do |name|
      define_method name do
        @project    = channel.projects.find_by_permalink!(params[:id])
        if name == :push_to_paid && @project.respond_to?(:use_stripe?) && @project.use_stripe? && @project.stripe_payout_status.to_s != 'paid'
          flash[:alert] = "Projet Stripe: l'etat paye est autorise uniquement apres confirmation bancaire Stripe payout.paid."
          return redirect_to :back
        end

        @project.send("#{name.to_s}!")
        redirect_to :back
      end
    end

    protected
    def begin_of_association_chain
      channel
    end

    def collection
      @projects = apply_scopes(channel.projects.page(params[:page]))
    end
  end
end
