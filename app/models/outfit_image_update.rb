require 'timeout'

class OutfitImageUpdate
  TIMEOUT_IN_SECONDS = 30
  
  @queue = :outfit_image_updates

  def self.perform(id)
    Timeout::timeout(TIMEOUT_IN_SECONDS) do
      Outfit.find(id).write_image!
    end
  end
  
  # Represents an outfit image update for an outfit that existed before this
  # feature was built. Its queue has a lower priority, so new outfits will
  # be updated before retroactively converted outfits.
  class Retroactive < OutfitImageUpdate
    @queue = :retroactive_outfit_image_updates
  end
end

