module HeroHeaderTagHelper
  # Hero banner at the top of project / event pages.
  #
  # The frame is locked to a 3:1 landscape ratio via `aspect-ratio: 3 / 1`,
  # with a max-height cap on tall viewports and a min-height floor on narrow
  # ones to stay visible on mobile.
  #
  # HeroImageUploader pre-processes every uploaded file to the same 3:1 ratio
  # (1500×500) with `resize_to_fill` (MiniMagick: scale-to-fit + center-crop,
  # the same technique Eventbrite, Meetup and Facebook Events use for cover
  # images). The image reaches the browser already matching the container's
  # ratio exactly, so `background-size: cover` has nothing to crop and
  # nothing to letterbox — no black bands, no visible distortion, for any
  # uploaded ratio (portrait, square, wide, screenshot, poster, …).
  #
  # Legacy files uploaded before the uploader change keep their original
  # ratio; `cover` will crop them lightly — strictly better than the previous
  # letterbox. Retroactive reprocess:
  #   Project.find_each { |p| p.hero_image.recreate_versions! if p.hero_image? }
  def hero_header_tag(object, options = {}, image = nil, &block)
    image ||= object.hero_image_url || '/assets/banner.jpg'

    content_tag :header,
                class: [:hero, :baniereImageProject, options[:class], image],
                style: "position: relative; overflow: hidden; " \
                       "width: 100%; aspect-ratio: 3 / 1; " \
                       "min-height: 200px; max-height: 60dvh; " \
                       "background-color: #B87333; " \
                       "background-image: url(#{image}); " \
                       "background-position: center; background-size: cover; " \
                       "background-repeat: no-repeat;",
                data: { 'image-url' => image_url(image) } do
      safe_join([
        content_tag(:div, '', class: 'hero-gradient', 'aria-hidden': true, style:
          "position: absolute; inset: 0; z-index: 1; pointer-events: none; " \
          "background: linear-gradient(to bottom, rgba(0,0,0,0) 55%, rgba(0,0,0,0.5) 100%);"),
        content_tag(:div, capture(&block), class: 'hero-content', style:
          "position: relative; z-index: 2;")
      ])
    end
  end
end
