module Neighborly::Mangopay
  class BankInformation < ActiveRecord::Base
    self.table_name = :bank_informations

    belongs_to :user, class_name: '::User'
    validates :iban, allow_blank: true, format: { with: /\A[a-zA-Z]{2}[0-9]{2}[a-zA-Z0-9]{4}[0-9]{7}([a-zA-Z0-9]?){0,16}?\Z/, message: "is not a valid IBAN number" }
    validates :bic, allow_blank: true, format: { with: /\A[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?\Z/, message: "is not a valid SWIFT/BIC code" }
    validates :us_account_number, allow_blank: true, format: { with: /\A[0-9]*\Z/, message: "must be composed of digits only" }
    validates :us_account_aba, allow_blank: true, format: { with: /\A[0-9]{9}\Z/, message: "must have 9 digits" }
    validates :ca_branch_code, allow_blank: true, format: { with: /\A[0-9]{5}\Z/, message: "must have 5 digits" }
    validates :ca_institution_number, allow_blank: true, format: { with: /\A[0-9]{3,4}\Z/, message: "must have 3 or 4 digits" }
    validates :ca_account_number, allow_blank: true, format: { with: /\A[0-9]{1,20}\Z/, message: "must be composed of digits only (20 digits max)" }
    validates :other_account_number, allow_blank: true, format: { with: /\A[0-9]*\Z/, message: "must be composed of digits only" }
    validates :other_bic, allow_blank: true, format: { with: /\A[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?\Z/, message: "is not a valid SWIFT/BIC code" }  

    validates_length_of :ca_bank_name, in: 3..50, allow_blank: true
    validates_length_of :other_country, in: 2..3, allow_blank: true

    before_save :save_or_update_mangopay_bank_account

    private

    def save_or_update_mangopay_bank_account
      fr_key = save_or_update_mangopay_fr_bank_account
      ca_key = save_or_update_mangopay_ca_bank_account
      us_key = save_or_update_mangopay_us_bank_account
      other_key = save_or_update_mangopay_other_bank_account 

      fr_key || ca_key || us_key || other_key
    end

    def save_or_update_mangopay_fr_bank_account
      mangopay_address = Hash.new
      mangopay_address['AddressLine1'] = self.owner_address
      mangopay_address['City'] = self.owner_city
      mangopay_address['PostalCode'] = self.owner_postal_code
      mangopay_address['Country'] = self.other_country
      return true unless iban.present? && bic.present?
      #return true unless iban_changed? || bic_changed?
      begin
        bank_account =  ::RecursiveOpenStruct.new(
                          ::MangoPay::BankAccount.create(self.user.mangopay_contributor.key,
                            {
                              OwnerName: user.name,
                              Type: "IBAN",
                              OwnerAddress: mangopay_address,
                              IBAN: iban,
                              BIC: bic
                            }
                          )
                        )
        self.key = bank_account.Id
        return key.present?
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "===MANGOPAY CREATION BANK ACCOUNT HAS FAILED========"
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end
    end

    def save_or_update_mangopay_ca_bank_account
      return true unless ca_branch_code.present? && ca_institution_number.present?
      return true unless ca_account_number.present? && ca_bank_name.present?
      return true unless ca_branch_code_changed? || ca_institution_number_changed?
      return true unless ca_account_number_changed? || ca_bank_name_changed?

      begin
        bank_account =  ::RecursiveOpenStruct.new(
                          ::MangoPay::BankAccount.create(self.user.mangopay_contributor.key,
                            {
                              Type: "CA",
                              OwnerName: user.name,
                              OwnerAddress: owner_address,
                              BranchCode: ca_branch_code,
                              InstitutionNumber: ca_institution_number,
                              AccountNumber: ca_account_number,
                              BankName: ca_bank_name
                            }
                          )
                        )
        self.ca_key = bank_account.Id
        puts "==================================================="
        puts "====MANGOPAY BANK ACCOUNT CREATION HAS SUCCEEDED=="
        puts "=====================#{bank_account}==============="
        puts "==================================================="
        return ca_key.present?
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "=====MANGOPAY BANK ACCOUNT CREATION HAS FAILED======="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end
    end

    
    def save_or_update_mangopay_other_bank_account
      return true unless other_bic.present? && other_account_number.present?
      return true unless other_account_number_changed? || other_bic_changed?

      mangopay_address = Hash.new
      mangopay_address['AddressLine1'] = owner_address
      mangopay_address['City'] = owner_city
      mangopay_address['PostalCode'] = owner_postal_code
      mangopay_address['Country'] = other_country
      begin
        bank_account =  ::RecursiveOpenStruct.new(
                          ::MangoPay::BankAccount.create(self.user.mangopay_contributor.key,
                            {
                              Type: "OTHER",
                              OwnerName: user.name,
                              OwnerAddress: mangopay_address,#has to be a hash in V 2.0.1
                              Country: other_country, 
                              AccountNumber: other_account_number,
                              BIC: other_bic
                            }
                          )
                        )
        self.other_key = bank_account.Id
        return other_key.present?
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "=====MANGOPAY BANK ACCOUNT CREATION HAS FAILED======="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end

    end


    def save_or_update_mangopay_us_bank_account
      return true unless us_account_number.present? && us_account_aba.present?
      return true unless us_account_number_changed? || us_account_aba_changed?

      begin
        bank_account =  ::RecursiveOpenStruct.new(
                          ::MangoPay::BankAccount.create(self.user.mangopay_contributor.key,
                            {
                              Type: "US",
                              OwnerName: user.name,
                              OwnerAddress: owner_address,
                              AccountNumber: us_account_number,
                              ABA: us_account_aba
                            }
                          )
                        )
        self.us_key = bank_account.Id
        return us_key.present?
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "=====MANGOPAY BANK ACCOUNT UPDATE HAS FAILED======="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end
    end
  end
end
