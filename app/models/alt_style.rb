class AltStyle < ApplicationRecord
  belongs_to :species
  belongs_to :color

  has_many :parent_swf_asset_relationships, as: :parent
  has_many :swf_assets, through: :parent_swf_asset_relationships

  def biology=(biology)
    # TODO: This is very similar to what `PetState` does, but like… much much
    # more compact? Idk if I'm missing something, or if I was just that much
    # more clueless back when I wrote it, lol 😅
    biology.values.each do |asset_data|
      self.swf_assets << SwfAsset.from_biology_data(self.body_id, asset_data)
    end
  end
end
