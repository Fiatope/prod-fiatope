require 'spec_helper'

describe Neighborly::Mangopay::Order do
  describe 'validations' do
    it { should validate_presence_of(:project) }
    it { should validate_presence_of(:href) }
  end
end
