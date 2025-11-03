require 'spec_helper'

describe SetLanguageController do

  describe "GET 'french'" do
    it "returns http success" do
      get 'french'
      response.should be_success
    end
  end

  describe "GET 'english'" do
    it "returns http success" do
      get 'english'
      response.should be_success
    end
  end

end
