class RewardPolicy < ApplicationPolicy
  include ProjectInheritedPolicyHelpers

  def update?
    create?
  end

  def contribution?
    create?
  end

  def sort?
    create?
  end

  def destroy?
    create? && not_sold_yet?
  end

  def permitted_attributes
    attributes = record.attribute_names.map(&:to_sym) +
    [articles_attributes: [ :id, :title, :description, :uploaded_image, :_destroy ]]

    if record.instance_of?(Reward)
      attributes.delete(:minimum_value) unless not_sold_yet?
      attributes.delete(:days_to_delivery) if project_finished?
    end

    { reward: attributes }
  end

  protected
  def not_sold_yet?
    record.try(:total_compromised) == 0
  end

  def project_finished?
    record.project.failed? || record.project.successful?
  end
end
