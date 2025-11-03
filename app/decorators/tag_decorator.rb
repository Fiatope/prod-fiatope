class TagDecorator < Draper::Decorator
  decorates :tag
  include Draper::LazyHelpers

  def display_name
    object.name.titleize
  end
end
