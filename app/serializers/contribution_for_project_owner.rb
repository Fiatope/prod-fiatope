class ContributionForProjectOwner
  include ActiveModel::Serialization

  attr_accessor :contribution

  delegate :user, :reward, :anonymous, :created_at, :confirmed_at,
    :payer_email, :payment_method, :project_id, :short_note, to: :contribution,
    allow_nil: true
  delegate :value, to: :contribution, prefix: true, allow_nil: true
  delegate :email, :name, to: :user, prefix: true, allow_nil: true
  delegate :description, :minimum_value, to: :reward, prefix: true, allow_nil: true

  def initialize(contribution)
    @contribution = contribution
  end

  def attributes
    {
      project_name:         project_name,
      reward_name:          reward_name,
      contribution_value:   contribution_value,
      created_at:           created_at,
      confirmed_at:         confirmed_at,
      user_email:           user_email,
      user_name:            user_name,
      payer_email:          payer_email,
      address_number:       address_number,
      payment_method:       payment_method,
      city:                 city,
      state:                state,
      anonymous:            anonymous,
      short_note:           short_note
    }
  end

  def project_name
    contribution.project.name
  end

  def address_number
    contribution.address_number || user.address_number
  end


  def reward_name
    rewards_name = ""
    if contribution.rewards && contribution.rewards.present?
      contribution.contribution_rewards.each do |cr|
        rewards_name << "#{cr.reward.title}x#{cr.quantity},"
      end
    end
    rewards_name
  end

  def complement
    contribution.address_complement || user.address_complement
  end

  def city
    contribution.address_city || user.address_city
  end

  def neighborhood
    contribution.address_neighborhood || user.address_neighborhood
  end

  def reward_id
    reward.try(:id) || 0
  end

  def state
    contribution.address_state || user.address_state
  end

  def street
    contribution.address_street || user.address_street
  end

  def zip_code
    contribution.address_zip_code || user.address_zip_code
  end
end
