require 'rails_helper'

RSpec.describe "MailingLists", type: :request do
  describe "GET /addUser" do
    it "returns http success" do
      get "/mailing_list/addUser"
      expect(response).to have_http_status(:success)
    end
  end

end
