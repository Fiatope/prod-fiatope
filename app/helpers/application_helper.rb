module ApplicationHelper
  # Visibilité des moyens de paiement pilotée par variable d'environnement.
  # PAYMENT_<NAME>_ENABLED absent ou 'true' => visible ; 'false' => masqué.
  def payment_method_visible?(name)
    flag = ENV["PAYMENT_#{name.to_s.upcase}_ENABLED"]
    flag.nil? ? true : flag.to_s.strip.downcase == 'true'
  end
end
