class HeroImageUploader < ImageUploader
  # Normalise every uploaded banner to the same 3:1 landscape frame (1500×500).
  #
  # Why: the page hero is displayed in a container with `aspect-ratio: 3 / 1`.
  # If the source image's ratio differs, pure CSS will either crop (cover) or
  # leave black bands (contain). Pre-processing the file at upload time to the
  # exact target ratio means the CSS fit is always perfect — no crop visible,
  # no bands — regardless of what the user uploads (portrait, square, wide).
  #
  # resize_to_fill (MiniMagick) = resize to fit, then center-crop the overflow.
  # This is the same technique Eventbrite, Meetup and Facebook Events use for
  # their cover images. `flatten_alpha` (inherited from ImageUploader) runs
  # before this to whiten transparency so center-crop never leaves grey borders.
  process resize_to_fill: [1500, 500]
  process convert: :jpg

  version :blur do
    process resize_to_limit: [2000, 0]
    process :apply_blur
    process quality: 70
  end

  def apply_blur
    manipulate! do |img|
      img.blur("0x5")
    end
  end

end
