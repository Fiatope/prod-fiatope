class StaticController < ApplicationController



  def terms
    render layout: false if request.xhr?
  end

  def privacy
    render layout: false if request.xhr?
  end

  def how_it_works; end
  def start_terms; end
  def start; end
  def faq; end

  def prix_fiatope
    order = []

    result = Project.where(id: [2635, 2358, 2638])

    result.each do |element|
      if element.id == 2635
        order[0] = element
      elsif element.id == 2358
        order[1] = element
      elsif element.id == 2638
        order[2] = element
      end
    end
    
    @projects_of_selected_entrepreneurs = order
  end

 

  def learn
    @presenter = LearnPagePresenter.new
  end

  def thank_you
    contribution = Contribution.find session[:thank_you_contribution_id]
    redirect_to [contribution.project, contribution]
  end

  def sitemap
    # TODO: update this sitemap to use new homepage logic
    @home_page    ||= Project.includes(:user, :category).visible.limit(6)
    @expiring     ||= Project.includes(:user, :category).visible.expiring.not_expired.order("created_at DESC").limit(3)
    @recent       ||= Project.includes(:user, :category).visible.not_expiring.not_expired.where("projects.user_id <> 7329").order('created_at DESC').limit(3)
    @successful   ||= Project.includes(:user, :category).visible.successful.order("created_at DESC").limit(3)
  end

end
