module Neighborly::Mangopay::Project
  extend ActiveSupport::Concern
  included do
    has_one :mangopay_wallet_handler, class_name: 'Neighborly::Mangopay::ProjectWalletHandler'
    has_many :orders, class_name: 'Neighborly::Mangopay::Order'

    def find_or_create_wallet
      if self.mangopay_wallet_handler.nil?
        project_wallet = ::MangoPay::Wallet.create(
          Owners:      [self.user.mangopay_contributor.key],
          Description: self.name,
          Currency:    self.currency.upcase
        )
        @project_wallet = self.create_mangopay_wallet_handler!(wallet_key: project_wallet['Id'])
      else
        @project_wallet = self.mangopay_wallet_handler
      end
    end

    def process_payout
      begin
        res = ::Neighborly::Mangopay::Payout.new(self).complete!
        return 'Payout processed successfully'
      rescue Exception => e
        return e.message
      end
    end

    def available_currencies
      ENV['CURRENCY'].split(',')
    end

    def currency_sym
      begin
        if currency == 'USD'
          "$"
        elsif currency == 'CAD'
          "C$"
        elsif currency == 'GBP'
          "£"
        elsif currency == 'CHF'
          "Fr" 
        else
          "€"
        end
      rescue
        "$"
      end
    end
  end

  def create_wallet_if_not_exists!
    return true if self.mangopay_wallet_handler.present?
    project_wallet = ::MangoPay::Wallet.create(
      Owners:      [::Neighborly::Mangopay::Customer.new(self.user, {}).fetch['Id']],
      Description: self.name,
      Currency:    self.currency.upcase
    )
    self.create_mangopay_wallet_handler!(wallet_key: project_wallet['Id'])
  end
end
