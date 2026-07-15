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

    OTHER_DOCUMENT_TYPE = %w{STATUS_PROOF REGISTER_PROOF}

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
      return self.mangopay_contributor_by_type.key if self.mangopay_contributor_by_type.present?
      @mangopay_contributor_key ||= Neighborly::Mangopay::Customer.new(self, {}).fetch['key']
    end

    def refund_ready?
      return bank_information.present? && bank_information.key.present?
    end

    def mangopay_document(kyc_object)
      document = nil
      user_kyc_docs = MangoPay::KycDocument.fetch(self.mangopay_contributor_key, kyc_object.document_key)
      if !user_kyc_docs.empty?
        if user_kyc_docs.is_a?(Hash)
          user_kyc_doc = user_kyc_docs
          if user_kyc_doc['Type'] == kyc_object.proof_type && user_kyc_doc['Id'] == kyc_object.document_key
            kyc_object.document_key = user_kyc_doc['Id']
            kyc_object.save!
            document = user_kyc_doc
          end
        else
          user_kyc_docs.each do |user_kyc_doc|
            if user_kyc_doc['Type'] == kyc_object.proof_type && user_kyc_doc['Id'] == kyc_object.document_key
              kyc_object.document_key = user_kyc_doc['Id']
              kyc_object.save!
              document = user_kyc_doc
            end
          end
        end
      end
      if document.nil?
        begin
          user_kyc_doc = MangoPay::KycDocument.create(self.mangopay_contributor_key, {
            Type: kyc_object.proof_type
          })
          kyc_object.document_key = user_kyc_doc['Id']
          kyc_object.save!
          document = user_kyc_doc
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
        Neighborly::Mangopay::Kyc.natural_document_type + OTHER_DOCUMENT_TYPE
      else
        Neighborly::Mangopay::Kyc.legal_document_type
      end
    end

    def kycs_available_type
      document_types - kycs.pluck(:proof_type)
    end

    # MangoPay est désactivé sur toute la plateforme (remplacé par Stripe Connect,
    # cf. app/models/concerns/stripe_project.rb). Ces documents ne sont plus jamais
    # vérifiés via l'API distante MangoPay: on renvoie uniquement les documents
    # déjà stockés localement (aucun appel réseau, aucune dépendance à MangoPay).
    def kycs_updatable_elements
      kycs.other_documents
    end

    def kycs_displayable_elements
      kycs.other_documents
    end

    def kycs_validated_elements
      []
    end

    def kycs_articles_of_association_elements
      []
    end

    def kycs_registration_proof_elements
      []
    end

    def update_mangopay_user
      # DÉSACTIVÉ si MANGOPAY_ENABLED n'est pas true
      return unless ENV['MANGOPAY_ENABLED']&.downcase == 'true'
      Neighborly::Mangopay::Customer.new(self, {}).update! if light_authentication_ready?
    end

    def mangopay_contributor_by_type
      if profile_type == "organization"
        self.mangopay_organization_contributor
      else
        self.mangopay_contributor
      end
    end

  end
end
