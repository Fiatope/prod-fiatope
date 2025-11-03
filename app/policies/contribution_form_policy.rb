class ContributionFormPolicy < ContributionPolicy
  def permitted_attributes
    attributes = super
    attributes[:contribution_form] = attributes.delete(:contribution)
    attributes.merge!({ user_articles: {} }, { reward_ids: {} } )
  end
end
