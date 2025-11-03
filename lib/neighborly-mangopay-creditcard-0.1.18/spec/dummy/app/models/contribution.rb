# Dummy class to be stubbed
class Contribution
  extend ActiveModel::Naming

  def self.find(*)
    new
  end

  def self.find_by(*)
    new
  end

  def cancel!(*);           end
  def confirm!(*);          end
  def update_attributes(*); end

  def id(*)
    42
  end

  def value(*)
    50
  end

  def project
    @project ||= Project.new
  end

  def user
    @user ||= User.new
  end
end
