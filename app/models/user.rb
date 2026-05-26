# coding: utf-8
# require 'state_machine'

class User < ActiveRecord::Base
  self.primary_key = 'id' 

  include User::Completeness,
          Shared::LocationHandler,
          PgSearch
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :lockable, :timeoutable and :omniauthable
  # :validatable

  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable, :omniauthable, :confirmable

  delegate :display_name, :display_image, :short_name, :display_image_html,
    :medium_name, :display_credits, :display_total_of_contributions, :first_name, :last_name, :gravatar_url,
    to: :decorator

  mount_uploader :uploaded_image, UserUploader, mount_on: :uploaded_image

  validates_length_of :bio, maximum: 140
  validates_presence_of :email
  validates_uniqueness_of :email, :allow_blank => true, :if => :email_changed?, :message => I18n.t('activerecord.errors.models.user.attributes.email.taken')
  validates_format_of :email, :with => Devise.email_regexp, :allow_blank => true, :if => :email_changed?

  validates_presence_of :password, :if => :password_required?
  validates_confirmation_of :password, :if => :password_confirmation_required?
  validates_length_of :password, :within => Devise.password_length, :allow_blank => true
  validates_presence_of :mobile_phone, if: :has_at_least_one_project?
  validates_format_of :mobile_phone, with: /[+]*[0-9 -]+/, if: :has_at_least_one_project?

  validates_presence_of :birthday
  validates :name, length: { in: 1..255, allow_nil: false }
  has_many :contributions
  has_many :matches
  has_many :projects
  has_many :notifications
  has_many :updates
  has_many :unsubscribes
  has_many :authorizations
  has_many :oauth_providers, through: :authorizations
  has_many :channels_subscribers
  has_one :user_total
  has_and_belongs_to_many :subscriptions, join_table: :channels_subscribers, class_name: 'Channel'
  has_one :channel
  has_one :organization, dependent: :destroy
  has_many :channel_members, dependent: :destroy
  has_many :channels, through: :channel_members, source: :channel
  has_and_belongs_to_many :recommended_projects, join_table: :recommendations, class_name: 'Project'
  has_one :investment_prospect, dependent: :destroy

  belongs_to :partner


  # acts_as_liker

  accepts_nested_attributes_for :authorizations
  accepts_nested_attributes_for :channel
  accepts_nested_attributes_for :organization
  accepts_nested_attributes_for :unsubscribes, allow_destroy: true rescue puts "No association found for name 'unsubscribes'. Has it been defined yet?"
  accepts_nested_attributes_for :investment_prospect

  pg_search_scope :pg_search, against: [
      [:name,  'A'],
      [:email, 'B'],
      [:bio,   'C'],
      [:id,    'D']
    ],
    associated_against: {
      organization: %i(name),
      channel:      %i(name),
    },
    using: {
      tsearch: {
        dictionary: 'english'
      }
    },
    ignoring: :accents

  scope :who_contributed_project, ->(project_id) {
    where("id IN (SELECT user_id FROM contributions WHERE contributions.state = 'confirmed' AND project_id = ?)", project_id)
  }

  scope :subscribed_to_updates, -> {
     where("id NOT IN (
       SELECT user_id
       FROM unsubscribes
       WHERE project_id IS NULL)")
   }

  scope :subscribed_to_project, ->(project_id) {
    who_contributed_project(project_id).
    where("id NOT IN (SELECT user_id FROM unsubscribes WHERE project_id = ?)", project_id)
  }

  state_machine :profile_type, initial: :personal do
    state :personal, value: 'personal'
    state :organization, value: 'organization'
    state :channel, value: 'channel'
  end

  PAYOUT_REQUIRED_KYC_TYPES = {
    'personal' => %w[IDENTITY_PROOF],
    'organization' => %w[IDENTITY_PROOF REGISTRATION_PROOF]
  }.freeze

  PAYOUT_REQUIREMENT_KYC_TYPES = [
    [/(individual|representative|person).*verification\.additional_document/i, 'ADDRESS_PROOF'],
    [/(individual|representative|person).*verification\.document/i, 'IDENTITY_PROOF'],
    [/company\.verification\.document/i, 'REGISTRATION_PROOF'],
    [/company\.verification\.additional_document/i, 'ARTICLES_OF_ASSOCIATION'],
    [/documents\.company_registration_verification/i, 'REGISTRATION_PROOF'],
    [/documents\.company_memorandum_of_association/i, 'ARTICLES_OF_ASSOCIATION']
  ].freeze

  PAYOUT_KYC_LABELS = {
    'IDENTITY_PROOF' => 'Piece d identite',
    'ADDRESS_PROOF' => 'Justificatif de domicile',
    'REGISTRATION_PROOF' => 'Extrait d immatriculation',
    'ARTICLES_OF_ASSOCIATION' => 'Statuts de l entreprise',
    'SHAREHOLDER_DECLARATION' => 'Declaration des actionnaires'
  }.freeze

  after_initialize :init

  def init
    self.nationality  ||= "FR"
    self.residence_country ||= "FR"
    self.confirmed_at = Time.now
  end


  def self.contribution_totals
    connection.select_one(
      self.all.
      joins(:user_total).
      select('
        count(DISTINCT user_id) as users,
        count(*) as contributions,
        sum(user_totals.sum) as contributed,
        sum(user_totals.credits) as credits').
      to_sql
    ).reduce({}){|memo,el| memo.merge({ el[0].to_sym => BigDecimal(el[1] || '0') }) }
  end

  def decorator
    @decorator ||= UserDecorator.new(self)
  end

  def credits
    user_total ? user_total.credits : 0.0
  end

  def total_contributed_projects
    user_total ? user_total.total_contributed_projects : 0
  end

  def facebook_id
    auth = authorizations.joins(:oauth_provider).where("oauth_providers.name = 'facebook'").first
    auth.uid if auth
  end

  def to_param
    return "#{self.id}" unless self.display_name
    "#{self.id}-#{self.display_name.parameterize}"
  end

  def total_contributions
    contributions.with_state('confirmed').not_anonymous.count
  end

  def updates_subscription
    unsubscribes.updates_unsubscribe(nil)
  end

  def project_unsubscribes
    Project.contributed_by(self).map do |p|
      unsubscribes.updates_unsubscribe(p.id)
    end
  end

  def projects_led
    projects.visible.not_soon
  end

  def total_led
    projects_led.count
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def password_confirmation_required?
    !new_record?
  end

  def confirmation_required?
    !confirmed? and not (authorizations.first and authorizations.first.oauth_provider == OauthProvider.where(name: 'facebook').first)
  end

  def formatted_address
    [
      [address_number, address_street].compact.join(' '),
      [address_zip_code, address_city].compact.join(' ')
    ].compact.join("\n")
  end

  def has_at_least_one_project?
    projects.any?
  end

  def payout_profile_required_kyc_types
    key = profile_type == 'organization' ? 'organization' : 'personal'
    (PAYOUT_REQUIRED_KYC_TYPES.fetch(key) + payout_profile_extra_required_kyc_types).uniq
  end

  def payout_kyc_label(proof_type)
    PAYOUT_KYC_LABELS[proof_type.to_s] || proof_type.to_s.humanize
  end

  def remember_payout_required_kyc_types_from_requirements(requirements)
    types = payout_kyc_types_for_requirements(requirements)
    if types.any?
      Rails.cache.write(payout_profile_required_kyc_cache_key, types, expires_in: 14.days)
    else
      clear_payout_required_kyc_types!
    end
    types
  rescue
    []
  end

  def clear_payout_required_kyc_types!
    Rails.cache.delete(payout_profile_required_kyc_cache_key)
  rescue
    nil
  end

  def payout_profile_missing_fields
    missing = []

    missing << 'Type de profil (particulier ou entreprise)' unless %w[personal organization].include?(profile_type)
    missing << 'Nom complet' if name.blank?
    missing << 'Date de naissance' if birthday.blank?
    missing << 'Nationalite' if nationality.blank?
    missing << 'Pays de residence' if residence_country.blank?

    if profile_type == 'organization'
      missing << 'Raison sociale de l entreprise' if organization.blank? || organization.name.blank?
      if organization.present? && organization.respond_to?(:registration_number) && organization.registration_number.blank?
        missing << 'Numero SIREN, SIRET ou RNA'
      end
    end

    info = bank_information
    if info.blank?
      missing << 'Adresse du titulaire du compte'
      missing << 'Ville du titulaire du compte'
      missing << 'Code postal du titulaire du compte'
      missing << 'IBAN du compte bancaire'
    else
      missing << 'Adresse du titulaire du compte' if info.owner_address.blank?
      missing << 'Ville du titulaire du compte' if info.owner_city.blank?
      missing << 'Code postal du titulaire du compte' if info.owner_postal_code.blank?
      missing << 'IBAN du compte bancaire' if info.iban.blank?
    end

    required_docs = payout_profile_required_kyc_types
    uploaded_docs = kycs.where(proof_type: required_docs).where.not(uploaded_image: [nil, '']).pluck(:proof_type).uniq
    (required_docs - uploaded_docs).each do |proof_type|
      missing << "Document manquant: #{payout_kyc_label(proof_type)}"
    end

    missing
  end

  def payout_profile_complete?
    payout_profile_missing_fields.empty?
  end

  private

  def payout_profile_extra_required_kyc_types
    Array(Rails.cache.read(payout_profile_required_kyc_cache_key)).map(&:to_s)
  rescue
    []
  end

  def payout_profile_required_kyc_cache_key
    "payout_profile_required_kyc_types:user:#{id}"
  end

  def payout_kyc_types_for_requirements(requirements)
    Array(requirements).flat_map do |requirement|
      requirement = requirement.to_s
      PAYOUT_REQUIREMENT_KYC_TYPES.each_with_object([]) do |(pattern, proof_type), types|
        types << proof_type if requirement.match?(pattern)
      end
    end.uniq
  end
end
