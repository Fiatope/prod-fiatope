class Contact < ActiveRecord::Base
  has_many :notifications
  validates :first_name, :last_name, :email, :organization_name, presence: true

  # La vue admin (gem neighborly-admin) attend un attribut `company_name`
  # qui n'existe pas en base ici (colonne réelle: organization_name).
  alias_attribute :company_name, :organization_name
end
