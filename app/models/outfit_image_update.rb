class OutfitImageUpdate
  @queue = :outfit_image_updates

  def self.perform(id)
    Outfit.find(id).write_image!
  end
end

