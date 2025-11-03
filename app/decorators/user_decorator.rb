class UserDecorator < Draper::Decorator
  decorates :user
  include Draper::LazyHelpers

  def gravatar_url
    return unless object.email
    "https://gravatar.com/avatar/#{Digest::MD5.new.update(object.email)}.jpg?size=150&default=#{::Configuration[:base_url]}/assets/default-avatars/#{[*1..11].sample}.png"
  end

  def display_name
    if object.organization? && object.organization.present?
      object.organization.name || I18n.t('words.no_name')
    elsif object.channel? && object.channel.present?
      object.channel.name
    else
      object.name || object.full_name || I18n.t('words.no_name')
    end
  end

  def display_image
    if object.organization? && object.organization.present?
      object.organization.image.large.url || '/assets/logo-blank.jpg'
    elsif object.channel? && object.channel.present?
      object.channel.image.large.url || '/assets/logo-blank.jpg'
    else
      object.uploaded_image.thumb_avatar.url || object.image_url || object.gravatar_url || "/assets/default-avatars/#{[*1..11].sample}.png"
    end
  end

  def display_image_html options={width: 150, height: 150}
    h.content_tag(:figure, h.image_tag(display_image, alt: object.display_name, style: "width: #{options[:width]}px; height: #{options[:height]}px", class: "avatar"), class: "profile-image #{object.profile_type}#{" #{options[:class]}" if options[:class].present?}").html_safe
  end

  def first_name
    display_name.split(' ').first
  end

  def last_name
    display_name.split(' ').last
  end

  def short_name
    truncate display_name, length: 20
  end

  def medium_name
    truncate display_name, length: 42
  end

  def display_credits
    number_to_currency object.credits
  end

  def display_total_of_contributions
    number_to_currency object.contributions.with_state('confirmed').sum(:value)
  end
end
