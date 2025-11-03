class ImportRequiredOauthProvider < ActiveRecord::Migration
  def change
    puts 'Creating OauthProvider entries...'
    categories = %w{twitter google_oauth2 linkedin}
    categories.each do |name|

      OauthProvider.find_or_create_by name: name do |provider|
        provider.path = name
        provider.secret = 'SOMETHING'
        provider.key = 'SOMETHING'
      end
    end

    #OauthProvider.find_or_create_by name: 'facebook' do |provider|
    #  provider.path = ENV['FACEBOOK_URL']
    #  provider.secret = ENV['FACEBOOK_SECRET']
    #  provider.key = ENV['FACEBOOK_APP_ID']
    #end

    puts '---------------------------------------------'
    puts 'Done!'
  end
end
