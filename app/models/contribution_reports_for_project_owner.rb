class ContributionReportsForProjectOwner
  include ActiveModel::Serialization
  include Enumerable

  attr_accessor :project, :conditions

  def initialize(project, conditions = {})
    @project, @conditions = project, conditions
  end

  def to_csv
    attributes = [
      'project_id',
      'project_name',
      'reward_name',
      'contribution_value',
      'created_at',
      'confirmed_at',
      'user_email',
      'user_name',
      'payer_email',
      'address_number',
      'payment_method',
      'city',
      'state',
      'anonymous',
      'short_note'
    ]


    CSV.generate(headers: true, :col_sep => "\t") do |csv|
     csv << attributes.map{ |attr| I18n.t "models.contribution_for_project_owner.#{attr}" }

      contributions.each do |contribution|
          csv << attributes.map{ |attr| contribution.send(attr) }
      end
    end


  end

  def all
    contributions
  end

  def each(&block)
    contributions.each do |contribution|
      block.call(contribution)
    end
  end

  private

  def contributions
    @contributions ||= project.contributions.with_state(:confirmed).where(conditions).map do |c|
      ContributionForProjectOwner.new(c)
    end
  end
end
