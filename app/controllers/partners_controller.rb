# coding: utf-8
class PartnersController < ApplicationController
  before_action do
    if action_name != "show"
      unless current_user && current_user.admin?
        redirect_to root_path, notice: "Seuls les admins ont accès à cette page"
      else
        true
      end
    else
      true
    end
  end

  def index
    @partners = Partner.all
  end

  def new
    @partner = Partner.new
  end

  def edit
    @partner = Partner.find(params[:id])
  end

  def show
    @partner = Partner.find_by_permalink(params[:id].try(:parameterize))

    @partner_projects = Project.where(partner_id: @partner.id, state: "online")
  end

  def create
    @partner = Partner.new(permitted_params[:partner])
    if @partner.save
      redirect_to edit_all_partners_path, notice: "Partenaire créé"
    else
      render :new, notice: "Ce partenaire n'a pas pu être créé"
    end
  end

  def update
    @partner = Partner.find(params[:id])
    @partner.assign_attributes(permitted_params[:partner])
    if @partner.save
      redirect_to edit_all_partners_path, notice: "Partenaire mis à jour avec succès"
    else
      render :new, notice: "Ce partenaire n'a pas pu être modifié"
    end
  end

  def admin
    @partner = Partner.find_by_permalink(params[:id].try(:parameterize))
    if user_signed_in?
      if current_user.admin? || current_user.admin_partner.include?(@partner.id)
        @projects = Project.where(partner_id: @partner.id)
        respond_to do |format|
          format.html
          format.csv
        end
        render layout: 'application_partner' and return
      else
        redirect_to root_path
      end
    else
      redirect_to root_path
    end
  end

  private
  def permitted_params
    params.permit(policy(@partner || Partner).permitted_attributes)
  end

end
