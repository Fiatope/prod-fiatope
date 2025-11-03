module Neighborly::Mangopay
  class PayoutsController < ApplicationController
    def create
      project = ::Project.find_by(permalink: params[:project_id])

      if project.present? && current_user.admin?
        returned_message = project.process_payout
        if returned_message == "Payout processed successfully"
          flash[:notice] = returned_message
        else
          flash[:alert] = returned_message
        end
      else
        returned_message = "The project does not exist or you're not an administrator"
        flash[:alert] = returned_message
      end

      redirect_to :back
    end
  end
end
