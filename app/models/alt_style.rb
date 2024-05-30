require "addressable/template"

class AltStyle < ApplicationRecord
  belongs_to :species
  belongs_to :color

  has_many :parent_swf_asset_relationships, as: :parent
  has_many :swf_assets, through: :parent_swf_asset_relationships
  has_many :contributions, as: :contributed, inverse_of: :contributed

  scope :matching_name, ->(series_name, color_name, species_name) {
    color = Color.find_by_name!(color_name)
    species = Species.find_by_name!(species_name)
    where(series_name:, color_id: color.id, species_id: species.id)
  }

  def name
    I18n.translate('pet_types.human_name', color_human_name: color.human_name,
                   species_human_name: species.human_name)
  end

  # If the series_name hasn't yet been set manually by support staff, show the
  # string "<New?>" instead. But it won't be searchable by that string—that is,
  # `fits:<New?>-faerie-draik` intentionally will not work, and the canonical
  # filter name will be `fits:alt-style-IDNUMBER`, instead.
  def series_name
    self[:series_name] || "<New?>"
  end

  # You can use this to check whether `series_name` is returning the actual
  # value or its placeholder value.
  def has_real_series_name?
    self[:series_name].present?
  end

  def adjective_name
    "#{series_name} #{color.human_name}"
  end

  THUMBNAIL_URL_TEMPLATE = Addressable::Template.new(
    "https://images.neopets.com/items/{series}_{color}_{species}.gif"
  )
  DEFAULT_THUMBNAIL_URL = "https://images.neopets.com/items/mall_bg_circle.gif"
  def thumbnail_url
    return DEFAULT_THUMBNAIL_URL unless has_real_series_name?

    # HACK: We're assuming this is the format long-term! But if it changes, we
    # may need to add it as a database field instead.
    THUMBNAIL_URL_TEMPLATE.expand(
      series: series_name.gsub(/\s+/, '').downcase,
      color: color.name.gsub(/\s+/, '').downcase,
      species: species.name.gsub(/\s+/, '').downcase,
    ).to_s
  end

  def preview_image_url
    swf_asset = swf_assets.first
    return nil if swf_asset.nil?

    swf_asset.image_url
  end

  # Given a list of item IDs, return how they look on this alt style.
  def appearances_for(item_ids, ...)
    Item.appearances_for(item_ids, self, ...)
  end

  def biology=(biology)
    # TODO: This is very similar to what `PetState` does, but like… much much
    # more compact? Idk if I'm missing something, or if I was just that much
    # more clueless back when I wrote it, lol 😅
    self.swf_assets = biology.values.map do |asset_data|
      SwfAsset.from_biology_data(self.body_id, asset_data)
    end
  end

  # For convenience in the console!
  def self.find_by_name(color_name, species_name)
    color = Color.find_by_name(color_name)
    species = Species.find_by_name(species_name)
    where(color_id: color, species_id: species).first
  end
end
