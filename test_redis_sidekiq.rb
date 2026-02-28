require_relative 'config/environment'

puts "=" * 80
puts "🧪 TEST REDIS & SIDEKIQ"
puts "=" * 80
puts ""

# Test Redis
puts "📍 Test connexion Redis..."
begin
  redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
  redis.ping
  puts "✅ Redis connecté : #{redis.ping}"
  redis.set("test_key", "test_value")
  value = redis.get("test_key")
  puts "✅ Redis lecture/écriture OK : #{value}"
  redis.del("test_key")
rescue => e
  puts "❌ Erreur Redis : #{e.message}"
end
puts ""

# Test Sidekiq
puts "📍 Test configuration Sidekiq..."
begin
  puts "✅ Sidekiq version : #{Sidekiq::VERSION}"
  puts "✅ Sidekiq redis : #{Sidekiq.redis_info}"
rescue => e
  puts "❌ Erreur Sidekiq : #{e.message}"
end
puts ""

puts "=" * 80
puts "✅ TESTS TERMINÉS !"
puts "=" * 80
