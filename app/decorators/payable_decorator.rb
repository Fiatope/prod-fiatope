class PayableDecorator < Draper::Decorator
  include Draper::LazyHelpers

  def display_value
    s = number_to_currency object.value
    cfa_value = object.value.to_s.to_d * conversion_rate.to_s.to_d
    
    if object.payment_method == "Orange Money"
      "#{cfa_value.round} CFA (= #{s})"
    else
      "#{s} (= #{cfa_value.round} CFA)"
    end
  end

  def conversion_rate
    ENV['CFA_CONVERSION_RATE'] || 656.56
  end

  def display_confirmed_at
    I18n.l(object.confirmed_at.to_date) if object.confirmed_at
  end
end
