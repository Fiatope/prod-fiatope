class ProjectPolicy < ApplicationPolicy
  def create?
    done_by_owner_or_admin? || is_channel_admin?
  end

  def update?
    create?
  end

  def show?
    if record.draft? || record.soon?
      create?
    else
      true
    end
  end

  def success?
    update?
  end

  def pay?
    update?
  end

  def reports?
    update?
  end

  def destroy?
    change_state? && record.can_push_to_trash?
  end

  def approve?
    change_state? && record.can_approve?
  end

  def launch?
    change_state? && record.can_launch?
  end

  def reject?
    change_state? && record.can_reject?
  end

  def push_to_draft?
    change_state? && record.can_push_to_draft?
  end

  def cancel?
    change_state? && record.can_cancel?
  end
  
  def push_to_request_funds?
    change_state? && record.can_push_to_request_funds?
  end

  def push_to_fraud_suspiscion?
    change_state? && record.can_push_to_fraud_suspiscion?
  end

  def push_to_paid?
    change_state? && record.can_push_to_paid?
  end

  def permitted_attributes
    if user.present? && (!record.instance_of?(Project) || fully_editable?)
      {
        project: record.attribute_names.map(&:to_sym) +
                [:location, :tag_list, :currency] -
                [
                  :online_date, :created_at, :updated_at, :about_html,
                  :budget_html, :english_html, :terms_html, :sent_to_analysis_at
                ]
      }
    else
      { project: [:name,          :category_id,          :permalink,
                  :about,         :video_url,            :uploaded_image,
                  :hero_image,    :headline,             :budget,
                  :english, :terms, :address_neighborhood, :location,
                  :address_city,  :address_state,        :hash_tag,
                  :site, :tag_list
                ]
      }


    end
  end

  protected

  def change_state?
    user.present? && (user.admin? || is_channel_admin?)
  end

  def fully_editable?
    record.instance_of?(Project) && ( !record.persisted? ||
                                      user.admin? ||
                                      (record.draft? ||
                                       record.rejected? ||
                                       record.soon?) )
  end

  def is_channel_admin?
    user.present? && ( record.last_channel.try(:user) == user ||
                       user.channels.include?(record.last_channel) )
  end

  class Scope < Struct.new(:user, :scope)
    def resolve
      if user.admin?
        scope
      else
        from_managed_channels = scope.joins(channels: :members).
          where(channel_members: { user_id: user.id })
        from_managed_directly = scope.where(user_id: user.id)
        scope.from("(#{from_managed_channels.to_sql} UNION #{from_managed_directly.to_sql}) as projects")
      end
    end
  end
end
