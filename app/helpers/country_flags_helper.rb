# frozen_string_literal: true

module CountryFlagsHelper
  # Custom/test countries need not have an ISO flag. Keep the native selector usable.
  def country_flag_asset_path(country)
    code = (country.respond_to?(:iso_alpha2) ? country.iso_alpha2 : country).to_s.downcase
    return unless /\A[a-z]{2}\z/.match?(code)

    path = "flags/#{code}.svg"
    return unless Rails.root.join('app/assets/images', path).file?

    image_path(path)
  end
end
