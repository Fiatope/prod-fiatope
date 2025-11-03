CatarseMonkeymail.configure do |config|
  config.api_key = ::Configuration[:mailchimp_api_key]
  config.list_id = ::Configuration[:mailchimp_list_id]
  config.successful_projects_list = ::Configuration[:mailchimp_successfull_list_id]
  config.failed_projects_list = ::Configuration[:mailchimp_failed_list_id]
end
