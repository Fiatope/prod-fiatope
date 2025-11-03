module Neighborly::Mangopay
  class Kyc < ActiveRecord::Base
    self.table_name = :kyc_files

    belongs_to :user, class_name: '::User'
    mount_uploader :uploaded_image, Neighborly::Mangopay::KycUploader, mount_on: :uploaded_image

    after_commit :send_to_mangopay
    # after_create :remove_old_document_with_same_type

    validates :user,
              :proof_type,
              :uploaded_image,
              presence: true

    NATURAL_DOCUMENT_TYPE = %w{IDENTITY_PROOF ADDRESS_PROOF}
    LEGAL_DOCUMENT_TYPE = %w{REGISTRATION_PROOF ARTICLES_OF_ASSOCIATION SHAREHOLDER_DECLARATION}

    def self.natural_document_type
      NATURAL_DOCUMENT_TYPE
    end

    def self.legal_document_type
      LEGAL_DOCUMENT_TYPE
    end

    # Mangopay : creation of a page into a given document
    def upload_document
      mangopay_document = self.user.mangopay_document(self)
      begin
        file_or_base64 = File.open(self.uploaded_image.path)
        base64 = (file_or_base64.is_a? File) ? Base64.encode64(file_or_base64.read) : file_or_base64
        MangoPay::KycDocument.create_page(self.user.contributor.key, mangopay_document.Id, base64)
      rescue Exception => e
        if e.message == "This document validation has already been treated"
          raise e.message
        else
          puts e.message
        end
      end

      begin
        MangoPay::KycDocument.update(self.user.mangopay_contributor_by_type.key, mangopay_document.Id, {
          Status: 'VALIDATION_ASKED'
        })
      rescue
        puts 'Validation already asked'
      end
    end

    private

    def send_to_mangopay
      self.upload_document
    end

    # def remove_old_document_with_same_type
    #   current_type = self.proof_type
    #   get_sibling_documents = self.user.kycs.where(proof_type: current_type)
    #   if get_sibling_documents.count > 1
    #     self.user.kycs.where(proof_type: current_type).order(created_at: :asc).first.destroy
    #   end
    # end

  end
end
