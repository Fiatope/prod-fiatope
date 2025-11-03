if Rails.env.production? && Configuration[:base_domain]
  Neighborly::Application.config.session_store(:cookie_store, key: Configuration[:secret_key_base], domain: Configuration[:base_domain])
else
  Neighborly::Application.config.session_store(:cookie_store, key: Configuration[:secret_key_base])
end
