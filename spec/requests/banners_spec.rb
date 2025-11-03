require 'rails_helper'

RSpec.describe "Banners", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/banners/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/banners/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/banners/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/banners/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
