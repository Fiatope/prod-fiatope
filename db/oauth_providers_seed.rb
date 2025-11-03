puts 'Creating OauthProvider entries...'

categories = %w{twitter google_oauth2 linkedin}
categories.each do |name|
  OauthProvider.create! name: name, path: name, secret: 'SOMETHING', key: 'SOMETHING'
end

OauthProvider.create! name: 'facebook', path: ENV['FACEBOOK_URL'], secret: ENV['FACEBOOK_SECRET'], key: ENV['FACEBOOK_APP_ID']

puts '---------------------------------------------'
puts 'Done!'
