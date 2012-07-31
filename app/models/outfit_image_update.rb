class OutfitImageUpdate
  @queue = :outfit_image_updates

  def self.perform(id)
    Outfit.find(id).write_image!
  end
  
  # Represents an outfit image update for an outfit that existed before this
  # feature was built. Its queue has a lower priority, so new outfits will
  # be updated before retroactively converted outfits.
  class Retroactive < OutfitImageUpdate
    @queue = :retroactive_outfit_image_updates
  end
end

