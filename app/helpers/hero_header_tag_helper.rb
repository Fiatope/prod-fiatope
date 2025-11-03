module HeroHeaderTagHelper
  def hero_header_tag(object, options = {}, image = nil, &block)
    image ||= object.hero_image_url || '/assets/banner.jpg'
    content_tag :header, capture(&block),
      class: [:hero, :baniereImageProject, options[:class], image],
      style: "background-image: linear-gradient(to bottom, rgba(255, 255, 255, 0), rgba(0, 0, 0, 0.6)), url(#{image}); background-repeat: no-repeat; background-position: center center; background-size: cover; min-height: 60dvh",
      data: { 'image-url' => image_url(image) }
  end
end
