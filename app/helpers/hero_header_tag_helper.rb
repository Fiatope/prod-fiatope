module HeroHeaderTagHelper
  # Hero banner at the top of project / event pages.
  #
  # We use `background-size: contain` for the uploaded image (NOT cover) so the
  # user's image is ALWAYS shown in its entirety, without any crop. Users were
  # frustrated because `cover` was cutting parts of the image off whenever the
  # container's aspect ratio did not match the uploaded image.
  #
  # Trade-off: when the image ratio differs from the header's ratio, empty
  # bands appear on the sides (or top/bottom). We fill them with the brand
  # color (`#B87333`) + the existing gradient overlay that still covers the
  # whole container (per-layer background-size: `100% 100%, contain`).
  def hero_header_tag(object, options = {}, image = nil, &block)
    image ||= object.hero_image_url || '/assets/banner.jpg'
    content_tag :header, capture(&block),
      class: [:hero, :baniereImageProject, options[:class], image],
      style: "background-image: linear-gradient(to bottom, rgba(255, 255, 255, 0), rgba(0, 0, 0, 0.6)), url(#{image}); " \
             "background-repeat: no-repeat, no-repeat; " \
             "background-position: center center, center center; " \
             "background-size: 100% 100%, contain; " \
             "background-color: #B87333; min-height: 60dvh",
      data: { 'image-url' => image_url(image) }
  end
end
