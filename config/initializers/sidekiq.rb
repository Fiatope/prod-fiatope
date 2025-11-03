Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'], namespace: "app3_sidekiq_#{Rails.env}" }
end