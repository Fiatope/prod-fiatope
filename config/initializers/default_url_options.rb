if Rails.env.production?
  clean_host = ::Configuration[:host].to_s.sub(%r{/*\z}, '')
  ActionMailer::Base.asset_host = clean_host
  Rails.application.routes.default_url_options = { host: clean_host }
else
  Rails.application.routes.default_url_options = { host: 'localhost:3000' }
end
