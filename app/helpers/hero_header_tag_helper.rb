module HeroHeaderTagHelper
  # Hero banner at the top of project / event pages.
  #
  # Rendering strategy: "ambient background" (the same technique Spotify,
  # Apple Music, YouTube and Eventbrite use on their hero images). Two copies
  # of the uploaded image are stacked:
  #
  #   1. BACKDROP — the image in `cover` mode, blurred and slightly darkened
  #      and zoomed. Fills 100% of the header regardless of ratio, giving a
  #      cinematic, visually coherent fill for the zones that a pure `contain`
  #      layout would otherwise leave empty.
  #   2. FOREGROUND — the same image in `contain` mode, centered, crisp.
  #      Guarantees the whole uploaded image is always visible, never cropped,
  #      regardless of its aspect ratio.
  #
  # A subtle bottom gradient keeps any foreground content legible. The backdrop
  # is wrapped in `transform: scale(1.15)` because `filter: blur` bleeds
  # transparent pixels at the edges otherwise. The brand-color fallback
  # (`#B87333`) is kept behind the backdrop in case the image fails to load.
  def hero_header_tag(object, options = {}, image = nil, &block)
    image ||= object.hero_image_url || '/assets/banner.jpg'
    image_css = "url(#{image})"

    content_tag :header,
                class: [:hero, :baniereImageProject, options[:class], image],
                style: "position: relative; overflow: hidden; " \
                       "background-color: #B87333; min-height: 60dvh;",
                data: { 'image-url' => image_url(image) } do
      safe_join([
        content_tag(:div, '', class: 'hero-ambient', 'aria-hidden': true, style:
          "position: absolute; inset: 0; z-index: 0; " \
          "background-image: #{image_css}; " \
          "background-position: center; background-size: cover; " \
          "background-repeat: no-repeat; " \
          "filter: blur(40px) brightness(0.65) saturate(1.1); " \
          "transform: scale(1.15);"),
        content_tag(:div, '', class: 'hero-foreground', 'aria-hidden': true, style:
          "position: absolute; inset: 0; z-index: 1; " \
          "background-image: #{image_css}; " \
          "background-position: center; background-size: contain; " \
          "background-repeat: no-repeat;"),
        content_tag(:div, '', class: 'hero-gradient', 'aria-hidden': true, style:
          "position: absolute; inset: 0; z-index: 2; pointer-events: none; " \
          "background: linear-gradient(to bottom, rgba(0,0,0,0) 55%, rgba(0,0,0,0.5) 100%);"),
        content_tag(:div, capture(&block), class: 'hero-content', style:
          "position: relative; z-index: 3;")
      ])
    end
  end
end
