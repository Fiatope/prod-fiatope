class Users::ContributionsController < ApplicationController
  after_action :verify_authorized, except: :index
  # after_action :verify_policy_scoped, only: :index
  inherit_resources
  defaults resource_class: Contribution
  belongs_to :user
  actions :index

  def index
    # authorize parent, :update?
    index!
  end

  def request_refund
    authorize resource
    # if !resource.user.refund_ready?
      # flash.alert = t('projects.new.not_mangopay_ready')
      # redirect_to payments_user_path(id: resource.user.to_param, redirect_url: credits_user_path(id: resource.user.to_param)) and return
    # end
    if resource.value > resource.user.user_total.credits || !resource.request_refund
      flash.alert = I18n.t('controllers.users.contributions.request_refund.insufficient_credits')
    else
      flash.notice = I18n.t('controllers.users.contributions.request_refund.refunded')
    end

    redirect_to credits_user_path(parent)
  end

  def tax_receipt
    @project      = parent
    @contribution = resource
    authorize resource
    respond_to do |format|
      format.pdf { render pdf: 'tax_receipt' }
    end
  end

  protected
  def policy_scope(scope)
    @_policy_scoped = true
    ContributionPolicy::UserScope.new(current_user, parent, scope).resolve
  end

  def collection
    @contributions ||= policy_scope(end_of_association_chain).
      order("created_at DESC, confirmed_at DESC").
      includes(:user, :reward, project: [:user, :category]).
      page(params[:page]).per(10)
  end
end
