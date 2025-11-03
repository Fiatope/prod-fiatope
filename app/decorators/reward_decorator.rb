class RewardDecorator < Draper::Decorator
  decorates :reward
  include Draper::LazyHelpers
  include AutoHtml

  def display_deliver_prevision
    I18n.l((object.project.expires_at + object.days_to_delivery.days), format: :prevision) rescue object.days_to_delivery
  end

  def display_remaining
    I18n.t('reward.display_remaining', remaining: object.remaining, maximum: object.maximum_contributions).html_safe
  end

  def display_minimum
    number_to_currency object.minimum_value, unit: object.project.currency_sym, precision: 0
  end

  def display_description
    auto_html(object.description) { simple_format; link(target: :blank) }
  end
end
