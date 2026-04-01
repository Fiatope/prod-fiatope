module Neighborly::Admin
  class ContributionsController < BaseController
    has_scope :by_user_id, :by_key, :user_name_contains, :user_email_contains, :payer_email_contains, :project_name_contains, :confirmed, :with_state, :by_value
    has_scope :credits, type: :boolean
    has_scope :between_values, using: [:start_at, :ends_at], allow_blank: true

    def self.contribution_actions
      %w[confirm pendent refund hide cancel push_to_trash].each do |action|
        define_method action do
          resource.send(action)
          flash.notice = I18n.t("neighborly.admin.contributions.messages.successful.#{action}")
          redirect_to contributions_path(params[:local_params])
        end
      end
    end
    contribution_actions

    def change_reward
      resource.change_reward! params[:reward_id]
      flash.notice = I18n.t("neighborly.admin.contributions.messages.successful.change_reward")
      redirect_to contributions_path(params[:local_params])
    end

    protected

    def collection
      filtered_scope = scoped_contributions

      @period_summary = if period_filter_active?
                          {
                            period: period_filter[:period],
                            start_at: period_filter[:start_at],
                            end_at: period_filter[:end_at],
                            contributions_count: filtered_scope.count,
                            total_collected: filtered_scope.sum(:value)
                          }
                        end

      @contributions = filtered_scope.order("contributions.created_at DESC").page(params[:page]) || []
    end

    def permitted_params
      params.permit({ contribution: Contribution.attribute_names.map(&:to_sym) })
    end

    private

    def scoped_contributions
      scope = apply_scopes(end_of_association_chain)
            .without_state("deleted")

          return scope unless period_filter_active?

          scope = scope.where(state: "confirmed")
           .where("COALESCE(contributions.value, 0) > 0")

      period_start = period_filter[:start_at]
      period_end = period_filter[:end_at]

      return scope if period_start.blank? && period_end.blank?
      return scope.where("contributions.created_at >= ?", period_start) if period_start.present? && period_end.blank?
      return scope.where("contributions.created_at <= ?", period_end) if period_start.blank? && period_end.present?

      scope.where(created_at: period_start..period_end)
    end

    def period_filter
      @period_filter ||= begin
        period = params[:period].presence

        if period.blank?
          { period: nil, start_at: nil, end_at: nil }
        elsif period == "custom"
          custom_start = parse_date(params.dig(:between_values, :start_at))
          custom_end = parse_date(params.dig(:between_values, :ends_at))

          {
            period: period,
            start_at: custom_start&.beginning_of_day,
            end_at: custom_end&.end_of_day
          }
        else
          reference = parse_date(params[:period_reference]) || Time.zone.today

          range = case period
                  when "day"
                    reference.beginning_of_day..reference.end_of_day
                  when "week"
                    reference.beginning_of_week.beginning_of_day..reference.end_of_week.end_of_day
                  when "month"
                    reference.beginning_of_month.beginning_of_day..reference.end_of_month.end_of_day
                  when "year"
                    reference.beginning_of_year.beginning_of_day..reference.end_of_year.end_of_day
                  else
                    nil
                  end

          {
            period: period,
            start_at: range&.begin,
            end_at: range&.end
          }
        end
      end
    end

    def period_filter_active?
      return false if period_filter[:period].blank?

      return true if %w[day week month year].include?(period_filter[:period])

      period_filter[:start_at].present? || period_filter[:end_at].present?
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
