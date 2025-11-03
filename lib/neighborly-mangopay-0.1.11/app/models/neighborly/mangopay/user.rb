module Neighborly::Mangopay::User
  extend ActiveSupport::Concern
  included do
    has_one :mangopay_contributor, class_name: 'Neighborly::Mangopay::Contributor', foreign_key: 'user_id'
    has_one :mangopay_organization_contributor, class_name: 'Neighborly::Mangopay::Contributor', foreign_key: 'organization_id'
    has_one :bank_information, class_name: 'Neighborly::Mangopay::BankInformation'
    has_many :registered_cards, class_name: 'Neighborly::Mangopay::RegisteredCard'
    has_many :orders, class_name: 'Neighborly::Mangopay::Order'
    has_many :kycs, class_name: 'Neighborly::Mangopay::Kyc'

    accepts_nested_attributes_for :kycs, :reject_if => :all_blank, :allow_destroy => true

    before_update :update_mangopay_user

    def registered_cards_with_currency(currency)
      registered_cards.where(currency: currency)
    end

    def firstname
      if name.present?
        name.split(' ').first
      end
    end

    def lastname
      if name.present?
        name.split(' ').last
      end
    end

    def address
      "#{address_number.to_s} #{address_street.to_s} #{address_complement}, #{address_zip_code.to_s}, #{address_city.to_s}"
    end

    def light_authentication_ready?
      if profile_type == "personal"
        return firstname.present? && lastname.present? && nationality.present? && residence_country.present? && birthday.present? 
      else
        return firstname.present? && lastname.present? && nationality.present? && residence_country.present? && birthday.present? && organization.present? && organization.name.present?
      end
    end

    def birthday_to_timestamp
      birthday.to_time.to_i
    end

    def mangopay_contributor_key
      return mangopay_contributor_by_type.key if mangopay_contributor_by_type.present?
      @mangopay_contributor_key ||= Neighborly::Mangopay::Customer.new(self, {}).fetch['Id']
    end

    def refund_ready?
      return bank_information.present? && bank_information.key.present?
    end

    def mangopay_document(kyc_object)
      document = MangoPay::KycDocument.fetch(self.mangopay_contributor_key, kyc_object.document_key)
      if document.nil?
        begin
          document = MangoPay::KycDocument.create(self.mangopay_contributor_key, {
            Type: kyc_object.proof_type
          })
          kyc_object.document_key = document.Id
          kyc_object.save
          document
        rescue MangoPay::ResponseError => ex
          puts "==================================================="
          puts "==== MANGOPAY SEARCH OF KYC DOC FOR #{self.mangopay_contributor_key} USER HAS FAILED==="
          puts "============== SEE RESCUE FOR MORE INFO ==========="
          puts "==================================================="
          puts "==================================================="
          puts ex.details
        end
      end
      document
    end

    def document_types
      if profile_type == "personal"
        Neighborly::Mangopay::Kyc.natural_document_type
      else
        Neighborly::Mangopay::Kyc.legal_document_type
      end
    end

    def kycs_available_type
      document_types - kycs.pluck(:proof_type)
    end

    def kycs_updatable_elements
      res = []
      kycs.each do |kyc|
        begin
          user_kyc_doc = MangoPay::KycDocument.fetch(self.mangopay_contributor.key, kyc.document_key)
          if !user_kyc_doc.empty?
            if user_kyc_doc['Status'] == 'CREATED'
              res << kyc
            end
            puts "==================================================="
            puts "===== MANGOPAY KYC DOC HAS STATUS CREATED ========="
            puts "================ #{res} ========================="
            puts "==================================================="
            puts "==================================================="
          end
        rescue MangoPay::ResponseError => ex
          puts "==================================================="
          puts "===== MANGOPAY KYC DOC HAS STATUS HAS FAILED======="
          puts "================ #{res} ========================="
          puts "==================================================="
          puts "==================================================="
          puts ex.details
        end
      end
      res
    end

    def kycs_displayable_elements
      res = []

      kycs.each do |kyc|
        begin
          status = ::RecursiveOpenStruct.new(MangoPay::KycDocument.fetch(self.mangopay_contributor_by_type.key, kyc.document_key)).Status
          if status != 'CREATED' && status != 'REFUSED'
            res << kyc
          end
        rescue MangoPay::ResponseError => ex
          puts ex.details
          puts 'Error while fetching displayable documents'
        end
      end

      res
    end

    def kycs_validated_elements
      res = []
      kycs.each do |kyc|
        begin
          user_kyc_doc = MangoPay::KycDocument.fetch(self.mangopay_contributor_by_type.key, kyc.document_key)
            if ! user_kyc_doc.empty?
              if user_kyc_doc['Status'] == 'VALIDATED'
                res << kyc
              end
            end
          rescue MangoPay::ResponseError => ex
            puts ex.details
            puts 'Error while fetching validated documents'
          end
      end

      res
    end

    def kycs_articles_of_association_elements
      res = []

      kycs.each do |kyc|
        begin
          type = ::RecursiveOpenStruct.new(MangoPay::KycDocument.fetch(self.mangopay_contributor_by_type.key, kyc.document_key)).Type
          res << kyc if type == 'ARTICLES_OF_ASSOCIATION'
        rescue  MangoPay::ResponseError => ex
          puts ex.details
          puts 'Error while fetching documents articles of association'
        end
      end

      res
    end

    def kycs_registration_proof_elements
      res = []
      kycs.each do |kyc|
        begin
          type = ::RecursiveOpenStruct.new(MangoPay::KycDocument.fetch(self.mangopay_contributor_by_type.key, kyc.document_key)).Type
          res << kyc if type == 'REGISTRATION_PROOF'
        rescue MangoPay::ResponseError => ex
          puts ex.details
          puts 'Error while fetching documents registration proof'
        end
      end

      res
    end

    def update_mangopay_user
      Neighborly::Mangopay::Customer.new(self, {}).update! if light_authentication_ready?
    end

    def mangopay_contributor_by_type
      if profile_type == "organization"
        mangopay_organization_contributor
      else
        mangopay_contributor
      end
    end

  end
end
