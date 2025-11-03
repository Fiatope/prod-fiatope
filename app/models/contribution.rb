class Contribution < ActiveRecord::Base
  include Shared::StateMachineHelpers,
          Shared::PaymentStateMachineHandler,
          Contribution::CustomValidators,
          Shared::Notifiable,
          Shared::Payable,
          PgSearch

  belongs_to :user
  belongs_to :project
  belongs_to :reward
  has_many :contribution_rewards
  has_many :rewards, through: :contribution_rewards

  belongs_to :matching
  has_many   :matchings
  has_one :match, through: :matching
  has_many :orange_money_transactions
  has_many :pay_plus_africa_transactions
  has_many :article_orders
  has_many :articles, through: :article_orders

  validates_presence_of :project, :user, :value

  scope :available_to_count,   -> { with_states(['confirmed', 'requested_refund', 'refunded']) }
  scope :available_to_display, -> { with_states(['confirmed', 'requested_refund', 'refunded']) }
  scope :anonymous,            -> { where(anonymous: true) }
  scope :credits,              -> { where(credits: true) }
  scope :not_anonymous,        -> { where(anonymous: false) }
  scope :confirmed_today,      -> { with_state('confirmed').where("contributions.confirmed_at::date = current_timestamp::date ") }
  scope :canceled_today,      -> { with_state('canceled').where("contributions.created_at::date = current_timestamp::date ") }
  scope :confirmed_this_hour, -> { where("(current_timestamp - contributions.confirmed_at) <= '1 hour'::interval") }
  scope :canceled_this_hour, -> { with_state('canceled').where("(current_timestamp - contributions.created_at) <= '1 hour'::interval") }
  scope :can_cancel,           -> { where("contributions.can_cancel") }
  # Contributions already refunded or with requested_refund should appear so that the user can see their status on the refunds list
  scope :can_refund,           ->{ where("contributions.can_refund") }

  before_create :compute_cfa_value

  pg_search_scope :pg_search, against: [
      [:key,            'A'],
      [:value,          'B'],
      [:payment_method, 'C'],
      [:payment_id,     'D']
    ],
    associated_against: {
      user:    %i(id name email),
      project: %i(name)
    },
    using: {
      tsearch: {
        dictionary: 'english'
      }
    },
    ignoring: :accents

  def matched_contributions
    self.class.where(matching_id: matchings)
  end

  def unique_identifier_for(provider_string)
    case provider_string
    when 'orange_money'
      "FTOPE-C#{id}-#{Time.now.to_i.to_s.last(8)}#{rand(1000)}"
    when 'pay_plus_africa'
      "FTOPE-C#{id}-#{Time.now.to_i.to_s.last(8)}#{rand(1000)}"
    end
  end

  def currency
    if self.payment_method == "Orange Money"
      "EUR"
    else
      self.project.currency
    end
  end

  def compute_cfa_value
    conversion_rate = ENV['CFA_CONVERSION_RATE'] || 656
    self.cfa_value = self.value.to_s.to_d * conversion_rate.to_s.to_d
  end

  def matches
    matched_contributions
  end

  def as_json(options = {})
    return super unless options.empty?

    PayableResourceSerializer.new(self).to_json
  end

  def recommended_projects
    user.recommended_projects.where("projects.id <> ?", project.id).order("count DESC")
  end

  def refund_deadline
    created_at + 180.days
  end

  def available_rewards
    Reward.where(project_id: self.project_id).where('minimum_value <= ?', self.value).order(:minimum_value)
  end

  def net_value
    if payment_service_fee_paid_by_user?
      value
    else
      value - payment_service_fee
    end
  end

  def payment_service_fee
    if match
      match.payment_service_fee / match.value * value
    else
      read_attribute(:payment_service_fee)
    end
  end
end
