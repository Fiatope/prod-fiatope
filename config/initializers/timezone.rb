# Configuration Timezone GeoNames (skip si GEO_USERNAME non défini - ex: build Docker)
if ENV['GEO_USERNAME'].present?
  Timezone::Lookup.config(:geonames) do |c|
    c.username = ENV['GEO_USERNAME']
  end
end
