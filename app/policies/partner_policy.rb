class PartnerPolicy < ApplicationPolicy

  def create?
    is_admin?
  end

  def update?
    create?
  end

  def index?
    is_admin?
  end

  def permitted_attributes
    { partner: record.attribute_names.map(&:to_sym) }
  end

end
