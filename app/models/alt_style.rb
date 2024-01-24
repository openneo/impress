class AltStyle < ApplicationRecord
  belongs_to :species
  belongs_to :color

  has_many :parent_swf_asset_relationships, as: :parent
  has_many :swf_assets, through: :parent_swf_asset_relationships
  has_many :contributions, as: :contributed, inverse_of: :contributed

  def name
    I18n.translate('pet_types.human_name', color_human_name: color.human_name,
                   species_human_name: species.human_name)
  end

  def thumbnail_url
    # HACK: Just assume this is a Nostalgic Alt Style, and that the thumbnail
    # is named reliably!
    "https://images.neopets.com/items/nostalgic_" +
      "#{color.name.gsub(/\s+/, '').downcase}_#{species.name.downcase}.gif"
  end

  MANIFEST_PATTERN = %r{^https://images.neopets.com/(?<prefix>.+)/(?<id>[0-9]+)(?<hash_part>_[^/]+)?/manifest\.json}
  def preview_image_url
    swf_asset = swf_assets.first
    return nil if swf_asset.nil?

    # HACK: Just assuming all of these were well-formed by the same process,
    # and infer the image URL from the manifest URL! But strictly speaking we
    # should be reading the manifest to check!
    match = swf_asset.manifest_url.match(MANIFEST_PATTERN)
    return nil if match.nil?
    
    "https://images.neopets.com/#{match[:prefix]}/" +
      "#{match[:id]}#{match[:hash_part]}/#{match[:id]}.png"
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
