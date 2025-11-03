class LovemoneyPresenter
  attr_reader :params, :lovemoney

  def initialize(params)
    @params   = ActiveSupport::HashWithIndifferentAccess.new(params)
    @lovemoney = Lovemoney.new(params)

    # Load projects
    projects
  end

  delegate :projects, :filters, to: :lovemoney

  def channels
    @channels ||=
      if filters.empty?
        Channel.with_state('online').order('RANDOM()').limit(4)
      else
        []
      end
  end

  def tags
    @tags ||= Tag.popular
  end

  def categories
    @categories ||= Category.with_projects
  end

  def locations
    @locations ||= Project.locations
  end

  def available_states
    @available_states ||=
      Lovemoney::STATES.map { |f| [I18n.t("lovemoney.index.states.#{f}"), f] }
  end

  def must_show_all_projects
    ActiveRecord::ConnectionAdapters::Column.
      value_to_boolean(params[:show_all_projects]) || params[:search].present?
  end
end
