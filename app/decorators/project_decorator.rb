class ProjectDecorator < Draper::Decorator
  decorates :project
  include Draper::LazyHelpers

  def remaining_text
    pluralize_without_number(time_to_go[:time], I18n.t('words.remaining_singular'), I18n.t('words.remaining_plural'))
  end

  def time_to_go
    time_and_unit = nil
    %w(day hour minute second).detect do |unit|
      time_and_unit = time_to_go_for unit
    end
    time_and_unit || time_and_unit_attributes(0, 'second')
  end

  def remaining_days
    object.time_to_go[:time]
  end

  def display_net_amount
    number_to_currency object.net_amount, unit: object.currency_sym ,precision: 0
  end

  def display_status
    if object.online?
      (object.reached_goal? ? 'reached_goal' : 'not_reached_goal')
    else
      object.state
    end
  end

  # Method for width of progress bars only
  def display_progress
    if object.total_contributions.zero?
      0
    else
      [
        [object.progress, 8].max,
        100
      ].min
    end
  end

  def display_progress_presale
    if object.total_contributions

      if object.total_contributions.zero?
        0
      end
    else
      [
        [progress_presale, 8].max,
        100
      ].min
    end
  end

  def display_image(version = 'project_thumb')
    use_uploaded_image(version) || use_video_tumbnail(version)
  end

  def display_address_formated
    text = ""
    if object.address_city || object.address_state
      # text += "#{object.address_neighborhood} // " unless object.address_neighborhood.blank?
      text += object.address_city unless object.address_city.blank?
      text += "#{object.address_city.present? ? ', ' : ''}#{object.address_state}" unless object.address_state.blank?
    end
    text
  end

  def display_video_embed_url
    if object.video_url.present?
      "//#{object.send(:video).embed_url}?title=0&byline=0&portrait=0&autoplay=0&color=ffffff&badge=0&modestbranding=1&showinfo=0&border=0&controls=2".gsub('http://', '')
    end
  end

  def display_online_date
    object.online_date ? I18n.l(object.online_date.to_date) : ''
  end

  def display_expires_at
    object.expires_at ? I18n.l(object.expires_at.to_date) : ''
  end

  def display_pledged
    number_to_currency object.pledged, unit: object.currency_sym, precision: 2
  end

  def display_goal
    number_to_currency object.goal, unit: object.currency_sym, precision: 2
  end

  def display_pledged_presale
    pledged_presale
  end

  def display_goal_presale
    goal = 0

    object.rewards.each do |reward|
      goal += reward.maximum_contributions unless reward.maximum_contributions.nil?
    end

    goal
  end

  def pledged_presale
    object.total_contributions
  end

  def progress_presale
    if object.presale_goal
      if object.presale_goal.zero?
        0
      
      else
        (pledged_presale.to_f / presale_goal.to_f * 100).to_i
      end
    else
      0
    end
  end

  def progress_bar
    classes = if display_progress == 100
      %i(green-bar progress round)
    else
      %i(progress round)
    end
    content_tag :div, class: classes do
      content_tag :span, nil, class: :meter, style: "width: #{display_progress}%"
    end
  end

  def progress_bar_presale
    classes = if display_progress_presale == 100
      %i(green-bar progress round)
    else
      %i(progress round)
    end
    content_tag :div, class: classes do
      content_tag :span, nil, class: "meter orange", style: "width: #{display_progress_presale}%"
    end
  end

  def cfa_progress_bar
    if cfa_progress >= 1
      classes = %i(green-bar progress round)
    else
      classes = %i(progress round)
    end

    cfa_percent = 100 * cfa_progress
    content_tag :div, class: classes do
      content_tag :span, nil, class: :meter, style: "width: #{cfa_percent}%"
    end
  end

  def cfa_progress
    cfa_contributions = object.contributions.with_state(:confirmed).where(payment_method: "Orange Money")
    (cfa_contributions.map(&:value).sum.to_f / object.goal.to_f)
  end

  def cfa_ratio
    return 0 if object.progress.to_d == 0
    (cfa_progress * 100) / object.progress.to_d
  end
  
  def total_cfa_collected
    cfa_contributions = object.contributions.with_state(:confirmed).where(payment_method: "Orange Money")
    cfa_contributions.map(&:cfa_value).compact.sum.round
  end

  def successful_flag
    return unless object.successful?

    content_tag(:div, class: [:successful_flag]) do
      image_tag("successful.#{I18n.locale}.png")
    end

  end

  def display_organization_type
    I18n.t("project.organization_type.#{object.organization_type}")
  end

  private

  def use_uploaded_image(version)
    object.uploaded_image.send(version).url
  end

  def use_video_tumbnail(version)
    object.video_thumbnail.send(version).url ||
      'image-placeholder-upload-in-progress.jpg'
  end

  def time_to_go_for(unit)
    time = 1.send(unit)

    if object.expires_at.to_i >= time.from_now.to_i
      time = ((object.expires_at - Time.zone.now).abs / time).round
      time_and_unit_attributes time, unit
    end
  end

  def time_and_unit_attributes(time, unit)
    { time: time, unit: pluralize_without_number(time, I18n.t("datetime.prompts.#{unit}").downcase) }
  end
end
